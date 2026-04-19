#!/bin/bash
# Open an interactive shell on the EC2 host or inside a container.
#
# Usage: ./scripts/shell.sh              # bash on the EC2 host
#        ./scripts/shell.sh web          # bash inside hoopsmgr-web
#        ./scripts/shell.sh mysql        # mysql client inside hoopsmgr-mysql
#        ./scripts/shell.sh react        # sh inside hoopsmgr-react (alpine)
#        ./scripts/shell.sh scraper      # bash inside hoopsmgr-scraper
#
# SSH security group is closed automatically when the shell exits.

source "$(dirname "$0")/_common.sh"
require_ssh_key

TARGET="${1:-}"

ssh_open
trap ssh_close EXIT

case "$TARGET" in
  "")
    remote_interactive
    ;;
  mysql)
    # Convenience: drop into the mysql client with creds from .env
    remote_interactive 'ROOTPASS=$(grep ^MYSQL_ROOT_PASSWORD= /opt/hoopsmgr/.env | cut -d= -f2-); docker exec -it hoopsmgr-mysql mysql -u root -p"$ROOTPASS" hoopsmgr'
    ;;
  react)
    # The nginx image is alpine-based, no bash
    remote_interactive "docker exec -it hoopsmgr-react sh"
    ;;
  web|scraper)
    remote_interactive "docker exec -it hoopsmgr-$TARGET bash"
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    echo "Valid: (none) | web | mysql | react | scraper" >&2
    exit 2
    ;;
esac
