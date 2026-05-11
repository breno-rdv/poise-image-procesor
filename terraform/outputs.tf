output "upload_bucket_name" {
  value = aws_s3_bucket.upload.bucket
}

output "thumbnail_bucket_name" {
  value = aws_s3_bucket.thumbnail.bucket
}

output "processing_queue_url" {
  value = aws_sqs_queue.processing.id
}

output "metadata_table_name" {
  value = aws_dynamodb_table.metadata.name
}

output "lambda_function_name" {
  value = aws_lambda_function.image_processor.function_name
}
