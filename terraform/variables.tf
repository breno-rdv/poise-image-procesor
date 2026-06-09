variable "project_name" {
  description = "Base name used for all resources"
  type        = string
  default     = "poise-image-processor"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "localstack" {
  description = "Set to true when running against LocalStack"
  type        = bool
  default     = false
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment zip produced by build.sh"
  type        = string
  default     = "../dist/function.zip"
}

variable "lambda_memory_mb" {
  description = "Lambda memory in MB. Python image processing typically needs 512–1024 MB"
  type        = number
  default     = 512
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "sqs_visibility_timeout_seconds" {
  description = "SQS message visibility timeout. Must be >= lambda_timeout_seconds"
  type        = number
  default     = 60
}

variable "lambda_architecture" {
  description = "CPU architecture. Must match the Pillow wheel platform used in build.sh (manylinux2014_x86_64 → x86_64)."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "lambda_architecture must be 'arm64' or 'x86_64'."
  }
}

variable "lambda_runtime" {
  description = "Lambda runtime identifier. Use 'python3.12' for the Python implementation."
  type        = string
  default     = "python3.12"
}

variable "sqs_max_receive_count" {
  description = "Number of times a message is received before being sent to the DLQ"
  type        = number
  default     = 3
}
