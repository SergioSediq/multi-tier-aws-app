# Deployment Guide

This guide walks you through deploying the Multi-Tier AWS Application.

## Prerequisites

1. **AWS Account**: Active AWS account with appropriate permissions
2. **AWS CLI**: Installed and configured (`aws configure`)
3. **Terraform**: Version >= 1.0
4. **Docker**: For building container images
5. **GitHub Account**: For CI/CD pipeline

## Initial Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd multi-tier-aws-app
```

### 2. Run Setup Script

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This script will:
- Check prerequisites
- Create S3 bucket for Terraform state
- Create DynamoDB table for state locking
- Create ECR repository for Docker images

### 3. Configure Terraform Backend

Edit `terraform/environments/dev/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "multi-tier-app/dev/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt = true
  }
}
```

### 4. Configure Variables

Copy the example variables file:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region = "us-east-1"
environment = "dev"
project_name = "multi-tier-app"

db_name = "appdb"
db_username = "admin"
# db_password should be set via environment variable or secrets manager

instance_type = "t3.micro"
min_size = 2
max_size = 10
desired_capacity = 2
```

### 5. Set Database Password

Set the database password as an environment variable:

```bash
export TF_VAR_db_password="your-secure-password"
```

Or use AWS Secrets Manager (recommended for production).

## Manual Deployment

### 1. Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

### 2. Review Plan

```bash
terraform plan
```

### 3. Apply Changes

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 4. Get Outputs

```bash
terraform output
```

Note the ALB DNS name and other important outputs.

## CI/CD Deployment

### 1. Configure GitHub Secrets

In your GitHub repository, go to Settings > Secrets and add:

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `DB_PASSWORD`: Database password

### 2. Push to Main Branch

The CI/CD pipeline will automatically:
1. Validate Terraform code
2. Run security scans (tfsec, Checkov)
3. Build Docker image
4. Push to ECR
5. Deploy infrastructure
6. Run integration tests

## Post-Deployment

### 1. Verify Deployment

Check the ALB health:

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
curl https://$ALB_DNS/health
```

### 2. Access Application

```bash
curl https://$ALB_DNS/
```

### 3. View CloudWatch Dashboard

1. Go to AWS Console > CloudWatch
2. Navigate to Dashboards
3. Open "multi-tier-app-dev-dashboard"

### 4. Test Auto Scaling

Generate load to test auto scaling:

```bash
# Install Apache Bench if needed
# On macOS: brew install httpd
# On Ubuntu: sudo apt-get install apache2-utils

ab -n 1000 -c 10 https://$ALB_DNS/
```

## Troubleshooting

### Application Not Responding

1. Check ALB target health in AWS Console
2. Check EC2 instance logs: `aws logs tail /ec2/multi-tier-app --follow`
3. Verify security groups allow traffic
4. Check RDS connectivity

### Database Connection Issues

1. Verify RDS is in private subnet
2. Check security group rules
3. Verify database credentials
4. Check RDS endpoint in application logs

### Terraform State Issues

1. Verify S3 bucket exists and is accessible
2. Check DynamoDB table for locks
3. Use `terraform force-unlock <LOCK_ID>` if needed

## Cost Optimization

1. **Reserved Instances**: Purchase RIs for predictable workloads
2. **S3 Lifecycle Policies**: Automatically configured
3. **Right-Sizing**: Monitor CloudWatch metrics and adjust instance types
4. **Auto Scaling**: Configured to scale down during low traffic

## Security Best Practices

1. **Secrets Management**: Use AWS Secrets Manager for production
2. **Encryption**: All data encrypted at rest and in transit
3. **Security Groups**: Least privilege access
4. **Regular Updates**: Keep AMIs and Docker images updated
5. **Security Scanning**: Automated in CI/CD pipeline

## Cleanup

To destroy all resources:

```bash
cd terraform/environments/dev
terraform destroy
```

**Warning**: This will delete all resources including databases. Ensure you have backups!
