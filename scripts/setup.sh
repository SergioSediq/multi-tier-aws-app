#!/bin/bash
# Setup script for Multi-Tier AWS Application

set -e

echo "Setting up Multi-Tier AWS Application..."

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1 || { echo "AWS credentials not configured. Run 'aws configure'." >&2; exit 1; }

# Create S3 bucket for Terraform state (if it doesn't exist)
echo "Setting up Terraform backend..."
read -p "Enter S3 bucket name for Terraform state: " STATE_BUCKET
read -p "Enter AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# Create bucket if it doesn't exist
if ! aws s3 ls "s3://${STATE_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket for Terraform state..."
    aws s3 mb "s3://${STATE_BUCKET}" --region "${AWS_REGION}"
    aws s3api put-bucket-versioning \
        --bucket "${STATE_BUCKET}" \
        --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption \
        --bucket "${STATE_BUCKET}" \
        --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
fi

# Create DynamoDB table for state locking (if it doesn't exist)
TABLE_NAME="terraform-state-lock"
if ! aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "Creating DynamoDB table for state locking..."
    aws dynamodb create-table \
        --table-name "${TABLE_NAME}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "${TABLE_NAME}" --region "${AWS_REGION}"
fi

# Create ECR repository (if it doesn't exist)
ECR_REPO="multi-tier-app"
if ! aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "Creating ECR repository..."
    aws ecr create-repository \
        --repository-name "${ECR_REPO}" \
        --region "${AWS_REGION}" \
        --image-scanning-configuration scanOnPush=true
fi

echo "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Update terraform/environments/dev/backend.tf with your S3 bucket name"
echo "2. Copy terraform/environments/dev/terraform.tfvars.example to terraform.tfvars"
echo "3. Fill in your values in terraform.tfvars"
echo "4. Run 'cd terraform/environments/dev && terraform init && terraform plan'"
