terraform {
  backend "s3" {
    # Configure these values for your S3 backend
    # bucket = "your-terraform-state-bucket"
    # key    = "multi-tier-app/dev/terraform.tfstate"
    # region = "us-east-1"
    # dynamodb_table = "terraform-state-lock"
    # encrypt = true
  }
}
