#!/bin/bash
# setup-ssl.sh — idempotent Let's Encrypt certificate issue-or-renew.
#
# On the EC2 host, decides based on what's already present:
#
#   * No live cert    → certbot certonly --standalone (stops react briefly
#                       to bind :80 for the ACME challenge; ~10s downtime).
#   * Live cert       → certbot renew --webroot -w /mnt/data/webroot
#                       (nginx keeps running; zero downtime).
#
# Every certbot call points at `/mnt/data/letsencrypt` so certs survive
# instance replacement (AMI rotation) alongside MySQL and media. Every
# call also registers a --deploy-hook that reloads nginx in the running
# react container on any successful renewal — so the twice-daily
# `/etc/cron.d/certbot-renew` cron (installed by user_data.sh) can run
# unattended and the site picks up the new cert without human help.
#
# Usage: ./scripts/setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>
#
# The wrapper `./scripts/renew-ssl.sh` fills in the laptop's defaults.

set -euo pipefail

EC2_IP=${1:?Usage: setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>}
SSH_KEY=${2:?Usage: setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>}
DOMAIN=${3:?Usage: setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>}
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Toggling SSH access open for setup-ssl..."
"$SCRIPT_DIR/ssh-toggle.sh" on
trap '"$SCRIPT_DIR/ssh-toggle.sh" off' EXIT

echo "==> setup-ssl on $DOMAIN via $EC2_IP..."

# All the actual work happens on the box. Passing DOMAIN in via env keeps
# the remote heredoc unquoted-safe (the inner script uses "$DOMAIN"
# literally — no laptop-side variable interpolation surprises).
ssh $SSH_OPTS ec2-user@$EC2_IP DOMAIN="$DOMAIN" bash -s << 'ENDSSH'
set -euo pipefail

DOMAIN="${DOMAIN:?DOMAIN must be set}"
CERT_DIR="/mnt/data/letsencrypt"
WEBROOT="/mnt/data/webroot"
LIVE_CERT="$CERT_DIR/live/$DOMAIN/fullchain.pem"
DEPLOY_HOOK="docker exec hoopsmgr-react nginx -s reload"

# Pre-flight: make sure the persistent dirs exist. On a freshly-provisioned
# instance user_data.sh already created these; on the current running EC2
# (pre-this-change) the webroot dir doesn't exist yet, so create it here.
sudo mkdir -p "$CERT_DIR" "$WEBROOT"

# All certbot calls use the same flags — factored so the branches below
# can't drift apart. --work-dir + --logs-dir stay off /mnt/data (they're
# ephemeral, no reason to burn EBS on them).
CERTBOT_BASE=(
  sudo certbot
  --config-dir "$CERT_DIR"
  --work-dir /var/lib/letsencrypt
  --logs-dir /var/log/letsencrypt
  --non-interactive
  --agree-tos
  --email "admin@$DOMAIN"
  --deploy-hook "$DEPLOY_HOOK"
)

if [ -f "$LIVE_CERT" ]; then
  echo "-- live cert found for $DOMAIN; running webroot renew"
  # `renew` re-uses the flags stored in the renewal config (including
  # the deploy hook), but we pass --webroot -w so a cert that was
  # originally issued in standalone mode gets migrated to webroot without
  # requiring the standalone chicken-and-egg dance again.
  "${CERTBOT_BASE[@]}" renew \
    --webroot -w "$WEBROOT" \
    --cert-name "$DOMAIN"
else
  echo "-- no live cert for $DOMAIN; running standalone issue"
  # First-time issue. Standalone mode needs :80, so stop the react
  # container for the ~10s certbot takes to answer the ACME challenge.
  cd /opt/hoopsmgr
  docker compose stop react || true
  "${CERTBOT_BASE[@]}" certonly \
    --standalone \
    -d "$DOMAIN" \
    -d "www.$DOMAIN"
  docker compose up -d react
fi

echo "-- cert status:"
"${CERTBOT_BASE[@]}" certificates 2>/dev/null | grep -E 'Certificate Name|Expiry Date|Domains' | sed 's/^/     /'
echo "==> setup-ssl complete for $DOMAIN"
ENDSSH
