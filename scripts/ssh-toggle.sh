#!/bin/bash
# Toggle SSH access on/off for the EC2 instance
# Usage: ./scripts/ssh-toggle.sh on|off
#
# Reads instance_id and ssh_security_group_id from Terraform outputs.
# 'on'  = attaches SSH security group to the instance
# 'off' = detaches SSH security group from the instance

set -e

ACTION=${1:?Usage: ssh-toggle.sh on|off}
REGION="us-east-1"

# Get values from Terraform outputs
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTANCE_ID=$(cd "$SCRIPT_DIR" && terraform output -raw instance_id)
SSH_SG_ID=$(cd "$SCRIPT_DIR" && terraform output -raw ssh_security_group_id)

if [ "$ACTION" = "on" ]; then
  echo "==> Enabling SSH access..."
  aws ec2 modify-instance-attribute \
    --instance-id "$INSTANCE_ID" \
    --groups $(aws ec2 describe-instance-attribute \
      --instance-id "$INSTANCE_ID" \
      --attribute groupSet \
      --query "Groups[].GroupId" \
      --output text \
      --region "$REGION") "$SSH_SG_ID" \
    --region "$REGION"

  PUBLIC_IP=$(cd "$SCRIPT_DIR" && terraform output -raw public_ip)
  echo "==> SSH enabled. Connect with:"
  echo "    ssh -i ~/.ssh/laptop_key.pem ec2-user@$PUBLIC_IP"

elif [ "$ACTION" = "off" ]; then
  echo "==> Disabling SSH access..."
  # Get current security groups, remove the SSH one
  CURRENT_SGS=$(aws ec2 describe-instance-attribute \
    --instance-id "$INSTANCE_ID" \
    --attribute groupSet \
    --query "Groups[].GroupId" \
    --output text \
    --region "$REGION")

  # Filter out the SSH security group
  NEW_SGS=$(echo "$CURRENT_SGS" | tr '\t' '\n' | grep -v "$SSH_SG_ID" | tr '\n' ' ')

  if [ -z "$NEW_SGS" ]; then
    echo "ERROR: Cannot remove all security groups. SSH SG is the only one attached."
    exit 1
  fi

  aws ec2 modify-instance-attribute \
    --instance-id "$INSTANCE_ID" \
    --groups $NEW_SGS \
    --region "$REGION"

  echo "==> SSH disabled. Port 22 is now closed."

else
  echo "Usage: ssh-toggle.sh on|off"
  exit 1
fi
