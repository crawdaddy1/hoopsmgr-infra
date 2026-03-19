#!/bin/bash
set -e

# Install Docker and Git
dnf update -y
dnf install -y docker git
systemctl enable docker
systemctl start docker

# Install Docker Compose
DOCKER_CONFIG=/usr/local/lib/docker/cli-plugins
mkdir -p $DOCKER_CONFIG
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o $DOCKER_CONFIG/docker-compose
chmod +x $DOCKER_CONFIG/docker-compose
ln -sf $DOCKER_CONFIG/docker-compose /usr/local/bin/docker-compose

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Create app directory
mkdir -p /opt/hoopsmgr
chown ec2-user:ec2-user /opt/hoopsmgr

# Install certbot for free SSL via Let's Encrypt
dnf install -y certbot

# Install AWS CLI for ECR login
dnf install -y aws-cli

# Set up ECR login cron (tokens expire every 12 hours)
cat > /etc/cron.d/ecr-login << 'CRON'
0 */6 * * * root aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${aws_region}.amazonaws.com
CRON

# Initial ECR login
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${aws_region}.amazonaws.com

echo "Server provisioned. Deploy with: docker compose pull && docker compose up -d"
