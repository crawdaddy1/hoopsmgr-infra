#!/bin/bash
# rotate-ami.sh — bring the EC2 onto the latest Amazon Linux 2023 AMI.
#
# Idempotent: if the pinned AMI is already current, exits 0 with no
# side effects. Safe to run on every deploy (deploy-latest.sh does).
#
# When a newer AMI is available it:
#   1. Snapshots the persistent data volume (safety net)
#   2. Updates terraform.tfvars to pin the new AMI
#   3. Runs `terraform plan` and shows the diff (expected: instance
#      replaces, EIP reattaches, data volume unchanged)
#   4. Prompts to confirm, then `terraform apply`
#   5. Prints the new public IP for the caller to consume
#
# After rotation, deploy.sh still has to run to bring containers up —
# rotation only swaps the host, the docker stack is brought up by the
# subsequent deploy step.
#
# Flags:
#   --check     Just print current vs latest, exit 0 if equal, 1 if drift.
#               Side-effect-free.
#   --yes       Don't prompt before applying. Useful for CI; risky locally
#               since rotation costs ~5 min of downtime.
#   --no-snapshot
#               Skip the pre-rotation EBS snapshot. Faster, but no rollback.
#
# Env overrides:
#   HOOPSMGR_SKIP_AMI_ROTATE=1   Force exit 0 immediately. deploy-latest.sh
#                                respects this so you can opt out per call.
#
# Requires: aws CLI logged in, terraform with state pulled.

set -euo pipefail

if [[ -n "${HOOPSMGR_SKIP_AMI_ROTATE:-}" ]]; then
  echo "rotate-ami: skipped (HOOPSMGR_SKIP_AMI_ROTATE set)"
  exit 0
fi

CHECK_ONLY=0
ASSUME_YES=0
SNAPSHOT=1

for arg in "$@"; do
  case "$arg" in
    --check)       CHECK_ONLY=1 ;;
    --yes|-y)      ASSUME_YES=1 ;;
    --no-snapshot) SNAPSHOT=0 ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "rotate-ami: unknown flag '$arg'" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TFVARS="$INFRA_DIR/terraform.tfvars"

cd "$INFRA_DIR"

# `terraform output` resolves the SSM-driven `latest_al2023_ami` data
# source live. It also surfaces `current_ami_id` from state — the AMI
# the running instance is actually on. Compare those to decide.
#
# Use -refresh=false on the read so we don't trigger a full state refresh
# every deploy; the SSM data source re-resolves on its own.
echo "rotate-ami: resolving latest AL2023 AMI..."
LATEST="$(terraform output -raw latest_al2023_ami 2>/dev/null || true)"
CURRENT="$(terraform output -raw current_ami_id 2>/dev/null || true)"

if [[ -z "$LATEST" ]]; then
  echo "rotate-ami: ERROR — could not read latest_al2023_ami output." >&2
  echo "  Have you run 'terraform init' and 'terraform apply' at least once" >&2
  echo "  since the SSM data source was added? See ami.tf." >&2
  exit 1
fi

# Fall back to reading the pinned value from tfvars if state output is
# empty (e.g. first-time bootstrap before apply).
if [[ -z "$CURRENT" ]]; then
  CURRENT="$(awk -F'=' '/^[[:space:]]*ec2_ami_id[[:space:]]*=/ {gsub(/[" ]/,"",$2); print $2; exit}' "$TFVARS" 2>/dev/null || true)"
fi

echo "  current: ${CURRENT:-<unset>}"
echo "  latest:  $LATEST"

if [[ "$CURRENT" == "$LATEST" ]]; then
  echo "rotate-ami: already on latest AMI. Nothing to do."
  exit 0
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "rotate-ami: drift detected (--check)."
  exit 1
fi

# Optional safety snapshot of the persistent data volume.
if [[ "$SNAPSHOT" -eq 1 ]]; then
  DATA_VOL="$(terraform output -raw data_volume_id 2>/dev/null || true)"
  if [[ -n "$DATA_VOL" ]]; then
    echo "rotate-ami: snapshotting data volume $DATA_VOL ..."
    aws ec2 create-snapshot \
      --volume-id "$DATA_VOL" \
      --description "hoopsmgr pre-ami-rotation $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=hoopsmgr-pre-ami-rotation}]" \
      --query 'SnapshotId' --output text
  else
    echo "rotate-ami: WARNING — no data_volume_id output; skipping snapshot." >&2
  fi
fi

# Update (or insert) ec2_ami_id in terraform.tfvars.
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if grep -qE '^[[:space:]]*ec2_ami_id[[:space:]]*=' "$TFVARS"; then
  # Use a temp file to avoid sed -i portability issues (BSD vs GNU).
  awk -v new="$LATEST" -v ts="$TIMESTAMP" '
    /^[[:space:]]*ec2_ami_id[[:space:]]*=/ {
      print "# Rotated by scripts/rotate-ami.sh on " ts
      print "ec2_ami_id    = \"" new "\""
      next
    }
    /^# Rotated by scripts\/rotate-ami\.sh/ { next }   # drop old timestamp
    { print }
  ' "$TFVARS" > "$TFVARS.tmp"
  mv "$TFVARS.tmp" "$TFVARS"
else
  {
    printf '\n# Rotated by scripts/rotate-ami.sh on %s\n' "$TIMESTAMP"
    printf 'ec2_ami_id    = "%s"\n' "$LATEST"
  } >> "$TFVARS"
fi

echo "rotate-ami: tfvars updated. Running terraform plan..."
terraform plan -out=ami-rotation.tfplan

if [[ "$ASSUME_YES" -ne 1 ]]; then
  echo
  echo "rotate-ami: review the plan above."
  echo "  EXPECTED: -/+ aws_instance.web (replacement)"
  echo "  EXPECTED: aws_ebs_volume.data UNCHANGED (data is preserved)"
  echo "  If the data volume shows -/+, ABORT and investigate."
  echo
  read -r -p "Apply this plan? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *)
      echo "rotate-ami: aborted by user. tfvars left edited; revert manually if desired."
      rm -f ami-rotation.tfplan
      exit 1
      ;;
  esac
fi

echo "rotate-ami: applying..."
terraform apply ami-rotation.tfplan
rm -f ami-rotation.tfplan

NEW_IP="$(terraform output -raw public_ip)"
NEW_CURRENT="$(terraform output -raw current_ami_id)"
echo
echo "rotate-ami: done."
echo "  new instance AMI: $NEW_CURRENT"
echo "  public IP:        $NEW_IP"
echo
echo "Next: run scripts/deploy.sh (or deploy-latest.sh) to bring containers"
echo "up on the new host. user_data has already mounted /mnt/data and"
echo "logged into ECR; the docker stack still has to be started."
