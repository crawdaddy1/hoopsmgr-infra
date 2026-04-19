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

# Mount the persistent data volume at ${data_mount_point}.
# Nitro instances (t3.*) expose EBS as NVMe devices, so the volume
# attached at ${data_device} appears as ${data_nvme_device}.
# Logic is idempotent: format only if unformatted, fstab-by-UUID so
# boot still succeeds (nofail) if the volume is missing.
DATA_DEVICE=""
for _ in $(seq 1 30); do
  for candidate in ${data_nvme_device} ${data_device}; do
    if [ -b "$candidate" ]; then
      DATA_DEVICE="$candidate"
      break 2
    fi
  done
  sleep 2
done

if [ -n "$DATA_DEVICE" ]; then
  if ! blkid "$DATA_DEVICE" > /dev/null 2>&1; then
    mkfs.ext4 -L hoopsmgr-data "$DATA_DEVICE"
  fi
  mkdir -p ${data_mount_point}
  DATA_UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
  if ! grep -q "$DATA_UUID" /etc/fstab; then
    echo "UUID=$DATA_UUID ${data_mount_point} ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  mount -a
  mkdir -p ${data_mount_point}/mysql ${data_mount_point}/letsencrypt ${data_mount_point}/media
else
  echo "WARNING: data volume not found at ${data_nvme_device} or ${data_device}" >&2
fi

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
