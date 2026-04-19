# IAM role for EC2 to pull images from ECR
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-ec2-role" }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "${var.project_name}-ecr-pull"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetAuthorizationToken"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "ses_send" {
  name = "${var.project_name}-ses-send"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail",
        "ses:GetSendQuota",
        "ses:GetSendStatistics"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# AMI is pinned via var.ec2_ami_id to prevent surprise instance
# replacement when AWS publishes a new Amazon Linux release. Persistent
# data (MySQL, Let's Encrypt certs, media) lives on aws_ebs_volume.data
# mounted at /mnt/data, so rotating the AMI replaces the instance but
# preserves the data volume. The attachment uses skip_destroy so
# Terraform won't try to detach the live volume while tearing down the
# old instance — AWS detaches automatically on instance termination.

# Security group - allow HTTP, HTTPS only (no SSH by default)
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-web-"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# Separate SSH security group - attached/detached on demand via scripts
resource "aws_security_group" "ssh" {
  name_prefix = "${var.project_name}-ssh-"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ssh-sg"
  }
}

# Elastic IP - free while attached to a running instance
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# EC2 instance - t3.micro free tier
resource "aws_instance" "web" {
  ami                    = var.ec2_ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = 30 # 30 GB free tier
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    domain_name      = var.domain_name
    aws_region       = var.aws_region
    data_device      = "/dev/sdf"
    data_nvme_device = "/dev/nvme1n1"
    data_mount_point = "/mnt/data"
  })

  tags = {
    Name = "${var.project_name}-web"
  }
}

# Persistent data volume — survives instance replacement so AMI rotations
# are safe. Holds MySQL data, Let's Encrypt certs, and Django media via
# bind mounts from /mnt/data in docker-compose.prod.yml.
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.web.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id

  # On instance replacement (e.g. AMI rotation), Terraform would normally
  # try to detach the volume before destroying the old instance. AWS
  # detaches automatically when an instance terminates, so skip the
  # explicit detach — avoids races and unnecessary API calls.
  skip_destroy = true
}
