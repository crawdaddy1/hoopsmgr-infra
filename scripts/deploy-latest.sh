#!/bin/bash
# Thin wrapper over deploy.sh with the known-good defaults for this
# laptop — so deploying doesn't require remembering the EC2 IP or
# which SSH key to use.
#
# Defaults can be overridden per-invocation, e.g.:
#   ./deploy-latest.sh v1.2.0
#   EC2_IP=1.2.3.4 ./deploy-latest.sh
#
# IP source: `terraform output public_ip` in this repo (falls back to
# the last-known pinned IP if terraform state isn't readable).
# SSH key:   verified by fingerprint match against AWS key pair
#            `laptop_key` (MD5 of DER-encoded public key) on 2026-04-20.
#
# AMI rotation: before deploying containers, this script invokes
# `rotate-ami.sh` to bump the EC2 onto the latest Amazon Linux 2023 AMI
# if a refresh is available. That keeps the host patched against new
# CVEs. The check is a fast no-op when already current; rotation
# (when needed) costs ~5 min of downtime as the instance is replaced.
# Skip the check with HOOPSMGR_SKIP_AMI_ROTATE=1.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_TAG="${1:-latest}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Step 1: rotate the AMI if a newer AL2023 has been published. No-op if
# we're already current. Rotation may replace the instance, so this has
# to happen BEFORE we try to read the public IP.
"$SCRIPT_DIR/rotate-ami.sh"

# Step 2: resolve the public IP from terraform state (post-rotation it
# may have changed). Fall back to the last-known pinned value so a
# missing terraform binary or state doesn't block routine deploys.
if [[ -z "${EC2_IP:-}" ]]; then
  EC2_IP="$(terraform -chdir="$INFRA_DIR" output -raw public_ip 2>/dev/null || true)"
fi
EC2_IP="${EC2_IP:-44.216.171.108}"

exec "$SCRIPT_DIR/deploy.sh" "$EC2_IP" "$SSH_KEY" "$IMAGE_TAG"
