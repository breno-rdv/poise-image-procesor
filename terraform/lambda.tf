resource "aws_lambda_function" "image_processor" {
  function_name = var.project_name

  # Quarkus native build produces target/function.zip containing a 'bootstrap' binary
  filename         = var.lambda_zip_path
  source_code_hash = fileexists(var.lambda_zip_path) ? filebase64sha256(var.lambda_zip_path) : null

  # Custom runtime — required for GraalVM native images
  runtime = "provided.al2023"

  # Quarkus Lambda ignores the handler value for native builds, but the field is required
  handler = "io.quarkus.amazon.lambda.runtime.QuarkusStreamHandler::handleRequest"

  role        = aws_iam_role.lambda_exec.arn
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = {
      DYNAMODB_TABLE    = aws_dynamodb_table.image_metadata.name
      THUMBNAILS_BUCKET = aws_s3_bucket.thumbnails.bucket
      RAW_BUCKET        = aws_s3_bucket.raw.bucket
      AWS_REGION_NAME   = var.aws_region
      QUARKUS_PROFILE   = "prod"
    }
  }

  tags = {
    Project = var.project_name
  }
}

# Wire SQS → Lambda: Lambda polls the queue and invokes itself with batches of messages
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.image_queue.arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = 10
  enabled          = true
}
