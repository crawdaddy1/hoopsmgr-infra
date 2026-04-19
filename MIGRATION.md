# Migration: Move persistent data to a dedicated EBS volume

This is a one-time migration. After it completes, AMI rotations (bumping
`var.ec2_ami_id`) are safe — the instance gets replaced, the data volume
stays.

## What moves

Today all state lives on the root EBS (destroyed on instance replacement):
- MySQL (Docker named volume `hoopsmgr_mysql_data` → `/var/lib/docker/volumes/…`)
- Let's Encrypt certs (`/etc/letsencrypt`, bind-mounted into the react container)
- Django media files (today, not persisted at all — lost on container restart)

After migration, all three live on `aws_ebs_volume.data`, mounted at
`/mnt/data` on the host, bind-mounted into the containers.

## Downtime

The site is down for the duration of step 4. For a site of this size,
expect **5–15 minutes** depending on MySQL data size.

## Prerequisites

- Merged PR: `hoopsmgr-infra` branch `feature/persistent-data-volume`
- PR branch checked out locally for `hoopsmgr`: `feature/persistent-data-volume`
  (ready but not merged — will be merged after verification)
- `aws` CLI logged in
- SSH key at `~/.ssh/laptop_key.pem`

---

## Step 1 — Snapshot the root volume (safety net)

If anything goes wrong, you can roll back by launching a new instance
from this snapshot.

```bash
cd ~/Projects/hoopsmgr-infra
INSTANCE_ID=$(terraform output -raw instance_id)
ROOT_VOL=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName==`/dev/xvda`].Ebs.VolumeId' \
  --output text)
aws ec2 create-snapshot --volume-id "$ROOT_VOL" \
  --description "hoopsmgr pre-data-volume-migration $(date +%Y-%m-%d)"
```

Wait for snapshot state `completed` before proceeding:

```bash
aws ec2 describe-snapshots --owner-ids self \
  --filters "Name=volume-id,Values=$ROOT_VOL" \
  --query 'Snapshots[].[SnapshotId,State,StartTime]' --output table
```

## Step 2 — Apply the infra PR

```bash
cd ~/Projects/hoopsmgr-infra
git checkout feature/persistent-data-volume
git pull
terraform plan
```

Expected plan: `+ aws_ebs_volume.data`, `+ aws_volume_attachment.data`,
`~ aws_instance.web` (user_data attribute changes only — no replacement).

If the instance shows `-/+` (replacement), **stop** — investigate before
proceeding.

```bash
terraform apply
```

Verify the volume attached:

```bash
DATA_VOL=$(terraform output -raw data_volume_id)
aws ec2 describe-volumes --volume-ids "$DATA_VOL" \
  --query 'Volumes[0].Attachments[0].[InstanceId,State,Device]' --output text
```

Should print `<instance-id> attached /dev/sdf`.

## Step 3 — Mount the volume and pre-create dirs on the running instance

The user_data script above only runs on first boot. The existing instance
needs the same setup done manually.

```bash
./scripts/ssh-toggle.sh on
PUBLIC_IP=$(terraform output -raw public_ip)
ssh -i ~/.ssh/laptop_key.pem ec2-user@$PUBLIC_IP
```

On the instance:

```bash
sudo bash <<'EOF'
set -e
# Find the newly attached device (Nitro remaps /dev/sdf -> /dev/nvme1n1)
for d in /dev/nvme1n1 /dev/sdf; do [ -b "$d" ] && DEV="$d" && break; done
echo "Using device: $DEV"

# Format (only if not already formatted — safety check)
if ! blkid "$DEV" > /dev/null 2>&1; then
  mkfs.ext4 -L hoopsmgr-data "$DEV"
fi

mkdir -p /mnt/data
UUID=$(blkid -s UUID -o value "$DEV")
grep -q "$UUID" /etc/fstab || \
  echo "UUID=$UUID /mnt/data ext4 defaults,nofail 0 2" >> /etc/fstab
mount -a
mkdir -p /mnt/data/mysql /mnt/data/letsencrypt /mnt/data/media
df -h /mnt/data
EOF
```

Expected: `/dev/nvme1n1` mounted at `/mnt/data` with ~10GB free.

Stay SSHed in for step 4.

## Step 4 — Stop stack, copy data, deploy new compose

**This is the downtime window.**

On the instance:

```bash
cd /opt/hoopsmgr
sudo docker compose stop
```

Copy MySQL data (preserve ownership — MySQL runs as UID 999 in-container):

```bash
sudo rsync -aHAX --info=progress2 \
  /var/lib/docker/volumes/hoopsmgr_mysql_data/_data/ \
  /mnt/data/mysql/
```

Copy Let's Encrypt certs:

```bash
sudo rsync -aHAX /etc/letsencrypt/ /mnt/data/letsencrypt/
```

Sanity check the copies:

```bash
ls -la /mnt/data/mysql/ | head     # should see ibdata1, mysql/, hoopsmgr/, …
ls /mnt/data/letsencrypt/live/     # should see hoopsmanager.com/
du -sh /mnt/data/mysql /mnt/data/letsencrypt
```

Log out of the SSH session. Back on your laptop:

```bash
cd ~/Projects/hoopsmgr
git checkout feature/persistent-data-volume  # the compose-changes PR branch
cd ~/Projects/hoopsmgr-infra
./scripts/deploy.sh $(terraform output -raw public_ip) ~/.ssh/laptop_key.pem
```

`deploy.sh` ships the new `docker-compose.prod.yml` (bind mounts from
`/mnt/data`) and runs `docker compose up -d`.

## Step 5 — Verify

- Site loads: `curl -sSf https://hoopsmanager.com/healthz`
- Login works with existing credentials
- `docker exec hoopsmgr-mysql mysql -uhoopsmgr -p$MYSQL_PASSWORD hoopsmgr -e 'SELECT COUNT(*) FROM main_user'`
  returns the expected count
- `docker inspect hoopsmgr-mysql | grep -A2 Mounts` shows `/mnt/data/mysql`

## Step 6 — Merge the compose PR and close SSH

```bash
cd ~/Projects/hoopsmgr
gh pr merge --squash    # or merge via GitHub UI
cd ~/Projects/hoopsmgr-infra
./scripts/ssh-toggle.sh off
```

## Step 7 — Prove AMI rotation now works

Pick the latest Amazon Linux 2023 AMI for us-east-1 and bump
`var.ec2_ami_id` in `terraform.tfvars`. `terraform plan` should show:

- `-/+ aws_instance.web` (replacement)
- `-/+ aws_eip.web` (reattach to new instance)
- `aws_ebs_volume.data` **unchanged**

Apply. When the new instance comes up:

- user_data auto-runs, finds the existing formatted volume (skips mkfs),
  adds fstab entry (or skips if already there), mounts at `/mnt/data`
- Redeploy via `./scripts/deploy.sh`
- Site is back with all original data

## Rollback

If step 4 or 5 fails:

1. The original data is still in the Docker named volume (rsync doesn't delete source).
2. `git checkout master` in `~/Projects/hoopsmgr`, re-run `deploy.sh` — ships the old compose, reads from the Docker named volume, site is restored.
3. If the instance itself is broken: launch a new instance from the snapshot taken in step 1.

## Leftover cleanup (after ~1 week of stable operation)

Once confident, remove the old Docker named volume and bind source:

```bash
# On the instance
sudo docker volume rm hoopsmgr_mysql_data
sudo rm -rf /etc/letsencrypt   # still referenced by /mnt/data/letsencrypt
```

(Snapshot can be kept longer or deleted via `aws ec2 delete-snapshot`.)
