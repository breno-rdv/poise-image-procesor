# Override values for LocalStack local development
# Usage: terraform apply -var-file="localstack.tfvars"

localstack        = true
aws_region        = "us-east-1"
lambda_zip_path   = "../dist/function.zip"
lambda_runtime    = "python3.12"
lambda_architecture = "x86_64"
