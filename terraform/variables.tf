variable "aws_region" {
  description = "AWS region where the infrastructure will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name used for AWS resources."
  type        = string
  default     = "poise-image-processor"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "lambda_zip_path" {
  description = "Path to the zipped Lambda function package."
  type        = string
  default     = "../dist/image-processor.zip"
}

variable "pillow_layer_zip" {
  description = "Path to the zipped Lambda layer containing Pillow."
  type        = string
  default     = "../dist/pillow-layer.zip"
}

variable "thumbnail_width" {
  description = "Generated thumbnail width."
  type        = number
  default     = 256
}

variable "thumbnail_height" {
  description = "Generated thumbnail height."
  type        = number
  default     = 256
}
