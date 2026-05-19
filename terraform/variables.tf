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
  description = "Path to the Lambda deployment zip (must contain a 'bootstrap' binary for GraalVM native)"
  type        = string
  default     = "../target/function.zip"
}

variable "lambda_memory_mb" {
  description = "Lambda memory in MB. Native images typically run well at 256 MB"
  type        = number
  default     = 256
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

variable "sqs_max_receive_count" {
  description = "Number of times a message is received before being sent to the DLQ"
  type        = number
  default     = 3
}
