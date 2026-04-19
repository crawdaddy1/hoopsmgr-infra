#!/bin/bash
# Shared helpers for hoopsmgr remote operation scripts.
# Sourced — not executed directly.
#
# Override defaults with env vars:
#   HOOPSMGR_EC2_IP=...           (default: 44.216.171.108)
#   HOOPSMGR_SSH_KEY=...          (default: ~/.ssh/laptop_key.pem)
#   HOOPSMGR_SKIP_TOGGLE=1        (don't open/close the SSH security group;
#                                  useful when running multiple wrappers in
#                                  one session — toggle manually around them)

set -euo pipefail

EC2_IP="${HOOPSMGR_EC2_IP:-44.216.171.108}"
# The AWS keypair is "laptop_key" but the local private key is the default
# ~/.ssh/id_rsa (the keypair was registered with that pubkey).
# Override with HOOPSMGR_SSH_KEY=/path/to/key.
SSH_KEY="${HOOPSMGR_SSH_KEY:-$HOME/.ssh/id_rsa}"
REMOTE_USER="ec2-user"

SSH_OPTS=(-o StrictHostKeyChecking=no -o LogLevel=ERROR)
# Only pass -i if the key file is actually readable. If not, ssh falls
# back to ssh-agent / default key paths (~/.ssh/id_rsa, ~/.ssh/id_ed25519, …).
if [[ -r "$SSH_KEY" ]]; then
  SSH_OPTS=(-i "$SSH_KEY" "${SSH_OPTS[@]}")
fi

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ssh_open() {
  [[ -n "${HOOPSMGR_SKIP_TOGGLE:-}" ]] && return 0
  "$_COMMON_DIR/ssh-toggle.sh" on >/dev/null
}

ssh_close() {
  [[ -n "${HOOPSMGR_SKIP_TOGGLE:-}" ]] && return 0
  "$_COMMON_DIR/ssh-toggle.sh" off >/dev/null 2>&1 || true
}

# Run a command or stdin heredoc on the EC2 box.
#   remote_run "uptime"
#   remote_run < script.sh
#   remote_run << 'EOF' ... EOF
remote_run() {
  if [[ $# -gt 0 ]]; then
    ssh "${SSH_OPTS[@]}" "$REMOTE_USER@$EC2_IP" "$@"
  else
    ssh "${SSH_OPTS[@]}" "$REMOTE_USER@$EC2_IP" bash -s
  fi
}

# Open an interactive ssh session on the EC2.
#   remote_interactive                          → host shell
#   remote_interactive docker exec -it foo bash → run interactive command
remote_interactive() {
  ssh -t "${SSH_OPTS[@]}" "$REMOTE_USER@$EC2_IP" "$@"
}

# Sanity-check that some key is available — either the configured file or
# at least one identity loaded into ssh-agent. Emit a clear message if not.
require_ssh_key() {
  if [[ -r "$SSH_KEY" ]]; then
    return 0
  fi
  if ssh-add -l >/dev/null 2>&1; then
    echo "Note: $SSH_KEY not readable; using ssh-agent identities instead." >&2
    return 0
  fi
  echo "ERROR: No usable SSH key. Tried:" >&2
  echo "  - $SSH_KEY (not readable)" >&2
  echo "  - ssh-agent (no identities loaded)" >&2
  echo "" >&2
  echo "Either set HOOPSMGR_SSH_KEY=/path/to/key, or load a key with ssh-add." >&2
  exit 1
}
