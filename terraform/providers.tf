terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # LocalStack credentials (any non-empty value works)
  access_key = var.localstack ? "test" : null
  secret_key = var.localstack ? "test" : null

  skip_credentials_validation = var.localstack
  skip_metadata_api_check     = var.localstack
  skip_requesting_account_id  = var.localstack

  # S3 path-style required for LocalStack
  s3_use_path_style = var.localstack

  dynamic "endpoints" {
    for_each = var.localstack ? [1] : []
    content {
      s3             = "http://localhost:4566"
      sqs            = "http://localhost:4566"
      lambda         = "http://localhost:4566"
      dynamodb       = "http://localhost:4566"
      iam            = "http://localhost:4566"
      sts            = "http://localhost:4566"
      cloudwatchlogs = "http://localhost:4566"
    }
  }
}
