# Log group must exist before Lambda starts — LocalStack does not auto-create it
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 7

  tags = {
    Project = var.project_name
  }
}

resource "aws_lambda_function" "image_processor" {
  function_name = var.project_name

  # Python deployment zip produced by build.sh
  filename         = var.lambda_zip_path
  source_code_hash = fileexists(var.lambda_zip_path) ? filebase64sha256(var.lambda_zip_path) : null

  # python3.12 runtime; use provided.al2023 only for native (non-Python) builds
  runtime = var.lambda_runtime

  # Python Lambda handler: module.file.function
  handler = "app.handler.handler"

  # Must match the architecture of the Pillow wheel installed by build.sh.
  # build.sh uses --platform manylinux2014_x86_64, so this must be x86_64.
  architectures = [var.lambda_architecture]

  role        = aws_iam_role.lambda_exec.arn
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  environment {
    variables = {
      DYNAMODB_TABLE    = aws_dynamodb_table.image_metadata.name
      THUMBNAILS_BUCKET = aws_s3_bucket.thumbnails.bucket
      RAW_BUCKET        = aws_s3_bucket.raw.bucket
      AWS_REGION_NAME   = var.aws_region
    }
  }

  # Log group must be created before Lambda so first invocation logs land somewhere
  depends_on = [aws_cloudwatch_log_group.lambda]

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
