# ── CloudWatch Log Groups ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "router" {
  name              = "/aws/lambda/${var.project_name}-router"
  retention_in_days = 7

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 7

  tags = {
    Project = var.project_name
  }
}

# ── Router Lambda ────────────────────────────────────────────────────────────
# Thin function: reads S3 notifications from the Standard intake queue, extracts
# dealer_id from the S3 key, and invokes the Image Processor Lambda directly
# using Lambda Tenant Isolation Mode (TenantId = dealer_id).

resource "aws_lambda_function" "router" {
  function_name = "${var.project_name}-router"

  filename         = var.lambda_zip_path
  source_code_hash = fileexists(var.lambda_zip_path) ? filebase64sha256(var.lambda_zip_path) : null

  runtime       = var.lambda_runtime
  handler       = "app.router.handler"
  architectures = [var.lambda_architecture]

  role        = aws_iam_role.router_lambda_exec.arn
  memory_size = 128   # routing is lightweight — just JSON parse + Lambda invoke
  timeout     = var.lambda_timeout_seconds

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.router.name
  }

  environment {
    variables = {
      PROCESSOR_FUNCTION_NAME = aws_lambda_function.image_processor.function_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.router,
    aws_lambda_function.image_processor
  ]

  tags = {
    Project = var.project_name
  }
}

# ── Image Processor Lambda ───────────────────────────────────────────────────
# Invoked directly by the Router Lambda with TenantId=dealer_id.
# Lambda Tenant Isolation Mode routes each invocation to a dealer-specific
# execution environment, preventing cross-tenant state leakage.
#
# NOTE: Tenant isolation mode must be enabled separately via AWS CLI until the
# Terraform AWS provider adds native support:
#   aws lambda put-function-event-invoke-config \
#     --function-name <name> \
#     --tenant-isolation-config '{"mode":"ENABLED"}'

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

# Standard SQS intake queue → Router Lambda
resource "aws_lambda_event_source_mapping" "intake_to_router" {
  event_source_arn = aws_sqs_queue.image_queue.arn
  function_name    = aws_lambda_function.router.arn
  batch_size       = 10
  enabled          = true
}


