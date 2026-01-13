terraform {
  backend "s3" {
    # Configure remote state backend
    # bucket         = "homelab-tf-state"
    # key            = "production/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "homelab-tf-locks"
    # encrypt        = true
    
    # For local development, use local backend
    # Comment out above and use local backend
  }
}

