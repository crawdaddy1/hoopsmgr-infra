# HoopsMgr Infrastructure

Terraform infrastructure for deploying HoopsMgr to AWS.

## Architecture

Single EC2 instance (t3.micro free tier) running all containers via Docker Compose, with ECR for container image storage.

| Resource | Cost |
|----------|------|
| EC2 t3.micro | Free (12 months) |
| EBS 30GB gp3 | Free (12 months) |
| Elastic IP | Free (while attached) |
| Route 53 hosted zone | ~$0.50/mo |
| ECR (3 repos, 3 images each) | ~$0.10/mo |
| SSL via Let's Encrypt | Free |

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5
- SSH key pair created in AWS (default: `laptop_key`)

## Setup

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

## Terraform Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | EC2 instance public IP |
| `domain_name` | Site domain (hoopsmanager.com) |
| `nameservers` | Route 53 nameservers (auto-applied to registrar) |
| `ssh_command` | SSH command to connect to the instance |
| `ecr_repository_urls` | ECR URLs for web, react, and bbref images |
| `instance_id` | EC2 instance ID (used by ssh-toggle script) |
| `ssh_security_group_id` | SSH security group ID (used by ssh-toggle script) |

View outputs anytime:
```bash
terraform output
terraform output public_ip
terraform output ecr_repository_urls
```

## Scripts

### SSH Toggle

SSH is **disabled by default** (port 22 closed). Use the toggle script to enable/disable on demand:

```bash
# Enable SSH access
./scripts/ssh-toggle.sh on

# Connect
ssh -i ~/.ssh/laptop_key.pem ec2-user@$(terraform output -raw public_ip)

# Disable SSH access when done
./scripts/ssh-toggle.sh off
```

### Deploy

Deploys container images from ECR to EC2. Automatically enables SSH before deploy and disables it after (even on failure).

```bash
# Deploy latest tag
./scripts/deploy.sh $(terraform output -raw public_ip) ~/.ssh/laptop_key.pem

# Deploy specific tag
./scripts/deploy.sh $(terraform output -raw public_ip) ~/.ssh/laptop_key.pem v1.0.0
```

### SSL Setup

Set up free SSL via Let's Encrypt (run once after first deploy):

```bash
./scripts/setup-ssl.sh $(terraform output -raw public_ip) ~/.ssh/laptop_key.pem hoopsmanager.com
```

## Build & Push Images (from hoopsmgr repo)

```bash
cd /path/to/hoopsmgr

# Build and push all images to ECR
./scripts/build-push.sh              # tags as 'latest'
./scripts/build-push.sh v1.0.0       # tags as 'v1.0.0'
```

## Full Deploy Workflow

```bash
# 1. Build and push images (from hoopsmgr repo)
cd ~/Projects/hoopsmgr
./scripts/build-push.sh v1.0.0

# 2. Deploy to EC2 (from hoopsmgr-infra repo)
cd ~/Projects/hoopsmgr-infra
./scripts/deploy.sh $(terraform output -raw public_ip) ~/.ssh/laptop_key.pem v1.0.0
```

## ECR Image Management

ECR lifecycle policies auto-delete images beyond the 3 most recent per repo. To manually check image counts:

```bash
aws ecr describe-images --repository-name hoopsmgr/web --query 'imageDetails[*].imageTags' --output table
aws ecr describe-images --repository-name hoopsmgr/react --query 'imageDetails[*].imageTags' --output table
aws ecr describe-images --repository-name hoopsmgr/bbref --query 'imageDetails[*].imageTags' --output table
```

## Security

- SSH (port 22) is **closed by default** and only opened on demand via `ssh-toggle.sh`
- Deploy script auto-opens and auto-closes SSH with a `trap` to ensure cleanup
- EC2 IAM role has ECR pull-only permissions
- MySQL is not exposed externally (container-to-container only)

## Project Structure

```
hoopsmgr-infra/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Terraform outputs
├── terraform.tfvars.example   # Template for your values
├── modules/
│   ├── networking/            # VPC, subnet, IGW, routes
│   ├── ec2/                   # Instance, security groups, IAM, EIP
│   ├── ecr/                   # Container repos + lifecycle policies
│   └── dns/                   # Route 53 zone + records
└── scripts/
    ├── deploy.sh              # Deploy images to EC2 (auto SSH toggle)
    ├── ssh-toggle.sh          # Enable/disable SSH on demand
    └── setup-ssl.sh           # Let's Encrypt SSL setup
```
