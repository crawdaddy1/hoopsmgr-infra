#!/bin/bash
# renew-ssl.sh — thin wrapper over setup-ssl.sh with the known-good
# defaults for this laptop. On-demand equivalent of the twice-daily
# `/etc/cron.d/certbot-renew` cron on the box — useful when you want
# to force a renewal now (e.g. after a cert-related outage) instead of
# waiting for the next scheduled run.
#
# Usage:
#   ./scripts/renew-ssl.sh                 # laptop defaults
#   ./scripts/renew-ssl.sh 1.2.3.4         # explicit IP
#   EC2_IP=… SSH_KEY=… DOMAIN=… ./scripts/renew-ssl.sh
#
# setup-ssl.sh detects whether a live cert exists; this wrapper stays
# oblivious to that. Both first-time issue and periodic renewal go
# through the same entry point.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# IP source order:
#   1. positional arg
#   2. EC2_IP env var (mirrors deploy-latest.sh)
#   3. terraform output -raw public_ip  (stays correct after AMI rotation)
#   4. last-known pinned IP fallback
EC2_IP="${1:-${EC2_IP:-}}"
if [[ -z "$EC2_IP" ]]; then
  EC2_IP="$(terraform -chdir="$INFRA_DIR" output -raw public_ip 2>/dev/null || true)"
fi
EC2_IP="${EC2_IP:-44.216.171.108}"

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
DOMAIN="${DOMAIN:-hoopsmanager.com}"

exec "$SCRIPT_DIR/setup-ssl.sh" "$EC2_IP" "$SSH_KEY" "$DOMAIN"
