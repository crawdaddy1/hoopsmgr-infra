#!/bin/bash
# Set up free SSL certificate via Let's Encrypt
# Run this AFTER deploy.sh and DNS is pointing to the server
# Usage: ./scripts/setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>

set -e

EC2_IP=${1:?Usage: setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>}
SSH_KEY=${2:?Usage: setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>}
DOMAIN=${3:?Usage: setup-ssl.sh <EC2_IP> <SSH_KEY_PATH> <DOMAIN>}
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"

echo "==> Setting up SSL for $DOMAIN on $EC2_IP..."

ssh $SSH_OPTS ec2-user@$EC2_IP << ENDSSH
# Stop nginx temporarily for certbot standalone mode
cd /opt/hoopsmgr/docker
docker compose stop react || true

# Get certificate
sudo certbot certonly --standalone \
  -d $DOMAIN \
  -d www.$DOMAIN \
  --non-interactive \
  --agree-tos \
  --email admin@$DOMAIN

# Restart containers
docker compose up -d

echo "==> SSL setup complete for $DOMAIN"
ENDSSH
