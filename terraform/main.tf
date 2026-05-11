provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix           = "${var.project_name}-${var.environment}"
  upload_bucket_name    = "${local.name_prefix}-upload"
  thumbnail_bucket_name = "${local.name_prefix}-thumbnail"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "upload" {
  bucket = local.upload_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "upload" {
  bucket = aws_s3_bucket.upload.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "upload" {
  bucket                  = aws_s3_bucket.upload.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "thumbnail" {
  bucket = local.thumbnail_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "thumbnail" {
  bucket = aws_s3_bucket.thumbnail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "thumbnail" {
  bucket                  = aws_s3_bucket.thumbnail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sqs_queue" "dlq" {
  name                    = "${local.name_prefix}-dlq"
  sqs_managed_sse_enabled = true
  tags                    = local.tags
}

resource "aws_sqs_queue" "processing" {
  name                       = local.name_prefix
  visibility_timeout_seconds = 180
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
  tags = local.tags
}

resource "aws_sqs_queue_policy" "processing" {
  queue_url = aws_sqs_queue.processing.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.processing.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.upload.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "upload_to_queue" {
  bucket = aws_s3_bucket.upload.id

  queue {
    queue_arn = aws_sqs_queue.processing.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.processing]
}

resource "aws_dynamodb_table" "metadata" {
  name         = "${local.name_prefix}-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.upload.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.thumbnail.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.processing.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.metadata.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_prefix}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_lambda_layer_version" "pillow" {
  layer_name          = "${local.name_prefix}-pillow"
  filename            = var.pillow_layer_zip
  source_code_hash    = filebase64sha256(var.pillow_layer_zip)
  compatible_runtimes = ["python3.12"]
}

resource "aws_lambda_function" "image_processor" {
  function_name    = local.name_prefix
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "app.lambda_handler"
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 60
  memory_size      = 512
  layers           = [aws_lambda_layer_version.pillow.arn]

  environment {
    variables = {
      THUMBNAIL_BUCKET = aws_s3_bucket.thumbnail.bucket
      METADATA_TABLE   = aws_dynamodb_table.metadata.name
      THUMBNAIL_WIDTH  = tostring(var.thumbnail_width)
      THUMBNAIL_HEIGHT = tostring(var.thumbnail_height)
      LOG_LEVEL        = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = local.tags
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.processing.arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = 1
  enabled          = true
}
