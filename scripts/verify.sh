#!/bin/bash
# Verify a hoopsmgr production deployment.
#
# Checks: container status & images, /healthz inside the web container,
# heartbeat log volume, MySQL row counts on key tables, public site response.
#
# Usage: ./scripts/verify.sh

source "$(dirname "$0")/_common.sh"
require_ssh_key

ssh_open
trap ssh_close EXIT

remote_run << 'REMOTE'
set +e
hr() { printf '\n=== %s ===\n' "$1"; }

hr "Container status"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

hr "/healthz from inside web container"
if docker exec hoopsmgr-web curl -fsS http://127.0.0.1:8000/healthz; then
  echo
  echo "OK"
else
  echo "FAILED — Django not responding on 8000 inside container"
fi

hr "Heartbeat log lines (last 100 web log lines)"
n=$(docker logs --tail 100 hoopsmgr-web 2>&1 | grep -c healthz_heartbeat)
echo "$n heartbeat line(s) found"
if [ "$n" -eq 0 ]; then
  echo "  (expected ~20/min once HEALTHCHECK is firing — could mean old image)"
fi

hr "MySQL row counts (key tables)"
ROOTPASS=$(grep '^MYSQL_ROOT_PASSWORD=' /opt/hoopsmgr/.env | cut -d= -f2-)
docker exec hoopsmgr-mysql mysql -u root -p"$ROOTPASS" hoopsmgr -B -N -e "
  SELECT 'auth_user',          COUNT(*) FROM auth_user
  UNION ALL SELECT 'owners_owner',    COUNT(*) FROM owners_owner
  UNION ALL SELECT 'owners_teams',    COUNT(*) FROM owners_teams
  UNION ALL SELECT 'players_player',  COUNT(*) FROM players_player
  UNION ALL SELECT 'mytxns_transaction', COUNT(*) FROM mytxns_transaction
  UNION ALL SELECT 'reference_players', COUNT(*) FROM reference_players;
" 2>/dev/null | column -t

hr "Public site response (HEAD https://hoopsmanager.com/)"
curl -sI --max-time 5 https://hoopsmanager.com/ | head -1 || echo "FAILED to reach public endpoint"

echo
REMOTE
