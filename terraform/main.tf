terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configure backend in terraform.tfvars or via environment variables
    # bucket = "your-terraform-state-bucket"
    # key    = "multi-tier-app/terraform.tfstate"
    # region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "multi-tier-aws-app"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name     = var.project_name
  environment      = var.environment
  vpc_cidr         = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  enable_nat_gateway = true
  enable_vpn_gateway  = false

  tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  vpc_id = module.vpc.vpc_id
  environment = var.environment

  tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.database_subnets
  db_name         = var.db_name
  db_username     = var.db_username
  db_password     = var.db_password
  db_instance_class = var.db_instance_class
  allocated_storage = var.allocated_storage
  db_subnet_group_name = module.vpc.database_subnet_group_id

  security_group_id = module.security_groups.rds_security_group_id

  tags = local.common_tags
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  certificate_arn = var.certificate_arn

  security_group_id = module.security_groups.alb_security_group_id

  tags = local.common_tags
}

# Auto Scaling Group Module
module "autoscaling" {
  source = "./modules/autoscaling"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  target_group_arns = [module.alb.target_group_arn]

  instance_type   = var.instance_type
  min_size        = var.min_size
  max_size        = var.max_size
  desired_capacity = var.desired_capacity

  security_group_id = module.security_groups.app_security_group_id
  db_endpoint       = module.rds.db_endpoint
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  docker_image      = var.docker_image
  key_name          = var.key_name

  tags = local.common_tags
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment

  tags = local.common_tags
}

# CloudFront Module
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name    = var.project_name
  environment     = var.environment
  s3_bucket_name  = module.s3.bucket_name
  alb_dns_name    = module.alb.dns_name
  certificate_arn = var.certificate_arn

  tags = local.common_tags
}

# Update S3 bucket policy with CloudFront distribution ARN
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = module.s3.bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name    = var.project_name
  environment     = var.environment
  alb_arn         = module.alb.alb_arn
  asg_name        = module.autoscaling.asg_name
  rds_instance_id = module.rds.db_instance_id

  tags = local.common_tags
}

# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
