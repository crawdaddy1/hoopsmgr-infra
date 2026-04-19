#!/bin/bash
# Tail logs from a hoopsmgr container.
#
# Usage: ./scripts/logs.sh <container> [N]
#   container : web | mysql | react | scraper
#   N         : number of lines (default 100); script follows after.
#
# Ctrl-C to exit. SSH security group is closed automatically on exit.

source "$(dirname "$0")/_common.sh"
require_ssh_key

NAME="${1:-}"
N="${2:-100}"

if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <web|mysql|react|scraper> [N]" >&2
  exit 2
fi

ssh_open
trap ssh_close EXIT

remote_interactive "docker logs --tail $N -f hoopsmgr-$NAME"
