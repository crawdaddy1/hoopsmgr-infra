terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "hoopsmgr-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "hoopsmgr-terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  aws_region   = var.aws_region
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}

module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  public_subnet_id  = module.networking.public_subnet_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  domain_name       = var.domain_name
  aws_region        = var.aws_region
}

module "dns" {
  source = "./modules/dns"

  domain_name = var.domain_name
  public_ip   = module.ec2.public_ip
}

module "ses" {
  source = "./modules/ses"

  domain_name = var.domain_name
  zone_id     = module.dns.zone_id
}

# ─── Grafana Cloud (dashboards, alerts) ────────────────────────
data "aws_secretsmanager_secret_version" "grafana_api_key" {
  secret_id = "hoopsmgr/grafana-cloud-api-key"
}

provider "grafana" {
  url  = var.grafana_url
  auth = data.aws_secretsmanager_secret_version.grafana_api_key.secret_string
}

module "grafana" {
  source = "./modules/grafana"

  grafana_url        = var.grafana_url
  grafana_api_key    = data.aws_secretsmanager_secret_version.grafana_api_key.secret_string
  notification_email = var.notification_email
}
