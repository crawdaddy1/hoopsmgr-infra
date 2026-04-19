#!/bin/bash
# Deploy hoopsmgr to EC2 by pulling images from ECR
# Usage: ./scripts/deploy.sh <EC2_IP> <SSH_KEY_PATH> [IMAGE_TAG]
# Example: ./scripts/deploy.sh 44.216.171.108 ~/.ssh/laptop_key.pem v1.0.0

set -e

EC2_IP=${1:?Usage: deploy.sh <EC2_IP> <SSH_KEY_PATH> [IMAGE_TAG]}
SSH_KEY=${2:?Usage: deploy.sh <EC2_IP> <SSH_KEY_PATH> [IMAGE_TAG]}
IMAGE_TAG=${3:-latest}
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"
REMOTE_USER="ec2-user"
APP_DIR="/opt/hoopsmgr"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_REPO_DIR="${HOOPSMGR_APP_DIR:-$(cd "$INFRA_DIR/../hoopsmgr" && pwd)}"

echo "==> Enabling SSH access for deployment..."
"$SCRIPT_DIR/ssh-toggle.sh" on

# Ensure SSH is disabled when script exits (success or failure)
trap '"$SCRIPT_DIR/ssh-toggle.sh" off' EXIT

echo "==> Deploying tag '$IMAGE_TAG' to $EC2_IP..."

# Copy compose file and env to server
scp $SSH_OPTS ${APP_REPO_DIR}/docker/docker-compose.prod.yml \
  $REMOTE_USER@$EC2_IP:$APP_DIR/docker-compose.yml
scp $SSH_OPTS ${APP_REPO_DIR}/docker/.env.prod \
  $REMOTE_USER@$EC2_IP:$APP_DIR/.env

ssh $SSH_OPTS $REMOTE_USER@$EC2_IP << ENDSSH
cd $APP_DIR

# Refresh ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 587079002533.dkr.ecr.us-east-1.amazonaws.com

# Set image tag and pull
export IMAGE_TAG=$IMAGE_TAG
docker compose pull
docker compose up -d

# Wait for MySQL to be ready, then run migrations
echo "Waiting for MySQL..."
for i in \$(seq 1 30); do
  docker exec hoopsmgr-web python -c "
import MySQLdb
try:
    MySQLdb.connect(host='mysql', user='hoopsmgr', passwd='hoopsmgr_pass', db='hoopsmgr')
    exit(0)
except:
    exit(1)
" 2>/dev/null && break
  sleep 2
done
docker exec hoopsmgr-web python manage.py migrate --noinput

# Restart Alloy so its loki.source.docker tailer drops stale handles
# from the just-recreated containers and picks up the new container
# IDs. Without this, log shipping stops on every deploy and Grafana
# fires a "Nginx Container Down" NoData alert.
sudo systemctl restart alloy.service

echo "==> Deployment complete!"
docker compose ps
ENDSSH
