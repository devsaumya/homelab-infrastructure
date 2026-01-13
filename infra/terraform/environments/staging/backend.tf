terraform {
  backend "s3" {
    # Configure remote state backend for staging
    # bucket         = "homelab-tf-state"
    # key            = "staging/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "homelab-tf-locks"
    # encrypt        = true
  }
}

