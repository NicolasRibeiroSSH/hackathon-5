terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "solidarytech-prod-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "solidarytech-prod-tflock"
    encrypt        = true
    profile        = "default"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "SolidaryTech"
      Environment = var.environment
      CostCenter  = "NGO-Core"
      ManagedBy   = "Terraform"
      Owner       = "platform-team"
    }
  }
}

# Região DR (us-east-2) — Warm Standby
provider "aws" {
  alias   = "dr"
  region  = var.dr_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "SolidaryTech"
      Environment = "${var.environment}-dr"
      CostCenter  = "NGO-Core"
      ManagedBy   = "Terraform"
      Owner       = "platform-team"
    }
  }
}

# ── Módulos ──────────────────────────────────────────────────────────────────

module "tfstate_backend" {
  source       = "./modules/tfstate-backend"
  project_name = var.project_name
  environment  = var.environment
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  repositories = var.ecr_repositories
}

module "rds" {
  source             = "./modules/rds"
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_instances       = var.rds_instances
}

module "dynamodb" {
  source       = "./modules/dynamodb"
  project_name = var.project_name
  environment  = var.environment
  table_name   = var.dynamodb_table_name
}

module "sqs" {
  source       = "./modules/sqs"
  project_name = var.project_name
  environment  = var.environment
  queue_name   = var.sqs_queue_name
}

module "ec2_k8s" {
  source             = "./modules/ec2-k8s"
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type      = var.k8s_instance_type
  key_name           = var.ssh_key_name
  rds_security_group_id = module.rds.security_group_id
  allowed_ssh_cidr   = var.allowed_ssh_cidr
}

module "budget" {
  source       = "./modules/budget"
  project_name = var.project_name
  environment  = var.environment
  monthly_limit_usd    = var.budget_monthly_limit
  alert_emails         = var.budget_alert_emails
}

# ── DR: VPC espelho em us-east-2 ─────────────────────────────────────────────

module "vpc_dr" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = "${var.environment}-dr"
  vpc_cidr     = var.vpc_cidr_dr

  providers = {
    aws = aws.dr
  }
}

module "rds_dr" {
  source             = "./modules/rds"
  project_name       = var.project_name
  environment        = "${var.environment}-dr"
  vpc_id             = module.vpc_dr.vpc_id
  private_subnet_ids = module.vpc_dr.private_subnet_ids
  db_instances       = var.rds_instances

  providers = {
    aws = aws.dr
  }
}

module "ec2_k8s_dr" {
  source             = "./modules/ec2-k8s"
  project_name       = var.project_name
  environment        = "${var.environment}-dr"
  vpc_id             = module.vpc_dr.vpc_id
  public_subnet_id   = module.vpc_dr.public_subnet_ids[0]
  private_subnet_ids = module.vpc_dr.private_subnet_ids
  instance_type      = var.k8s_instance_type_dr
  key_name           = var.ssh_key_name
  rds_security_group_id = module.rds_dr.security_group_id
  allowed_ssh_cidr   = var.allowed_ssh_cidr

  providers = {
    aws = aws.dr
  }
}
