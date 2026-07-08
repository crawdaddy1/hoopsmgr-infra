# Latest Amazon Linux 2023 x86_64 AMI lookup.
#
# Read from the AWS-published SSM parameter — the canonical "latest AL2023"
# pointer. Faster and less brittle than filtering describe-images output
# (no name-glob to maintain, no most_recent ordering surprises).
#
# This data source is INFORMATIONAL ONLY. It does NOT drive
# `aws_instance.web.ami`, which stays pinned via `var.ec2_ami_id` so
# routine `terraform apply` runs don't surprise-replace the instance
# when AWS publishes a new AL2023 release.
#
# Surfaced as the `latest_al2023_ami` root output so `scripts/rotate-ami.sh`
# can diff it against the currently-pinned value and explicitly rotate
# when a newer AMI ships. AMI rotation = instance replacement, ~5 min of
# downtime; persistent state survives because MySQL / certs / media live
# on `aws_ebs_volume.data` (mounted at /mnt/data, prevent_destroy = true).
data "aws_ssm_parameter" "al2023_latest" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
