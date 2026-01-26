# Configure Terraform and AWS Provider
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

# AWS Provider - connects to your AWS account
provider "aws" {
  region = "ap-southeast-1"  # Singapore region (matches your ECR)
}

