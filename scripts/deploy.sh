#!/bin/bash
# Deployment script for Multi-Tier AWS Application

set -e

ENVIRONMENT=${1:-dev}
WORKING_DIR="terraform/environments/${ENVIRONMENT}"

if [ ! -d "$WORKING_DIR" ]; then
    echo "Error: Environment directory $WORKING_DIR does not exist"
    exit 1
fi

cd "$WORKING_DIR"

echo "Deploying to $ENVIRONMENT environment..."

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "Planning deployment..."
terraform plan -out=tfplan

# Apply changes
read -p "Do you want to apply these changes? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
    echo "Applying changes..."
    terraform apply tfplan
    echo "Deployment completed successfully!"
    
    # Display outputs
    echo ""
    echo "Deployment outputs:"
    terraform output
else
    echo "Deployment cancelled."
fi
