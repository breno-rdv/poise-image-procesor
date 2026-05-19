output "raw_bucket_name" {
  description = "S3 bucket that receives raw image uploads"
  value       = aws_s3_bucket.raw.bucket
}

output "thumbnails_bucket_name" {
  description = "S3 bucket where generated thumbnails are stored"
  value       = aws_s3_bucket.thumbnails.bucket
}

output "sqs_queue_url" {
  description = "URL of the main image processing queue"
  value       = aws_sqs_queue.image_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the main image processing queue"
  value       = aws_sqs_queue.image_queue.arn
}

output "sqs_dlq_url" {
  description = "URL of the dead-letter queue"
  value       = aws_sqs_queue.dlq.url
}

output "dynamodb_table_name" {
  description = "DynamoDB table storing image metadata"
  value       = aws_dynamodb_table.image_metadata.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.image_processor.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.image_processor.arn
}
