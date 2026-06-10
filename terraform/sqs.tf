# Dead-letter queue for the Standard intake queue
resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-dlq"

  # Keep failed messages for 14 days for debugging
  message_retention_seconds = 1209600

  tags = {
    Project = var.project_name
  }
}

# Standard intake queue — receives S3 event notifications.
# The Router Lambda consumes this queue and invokes the Image Processor Lambda
# directly using Lambda Tenant Isolation Mode (no FIFO queue needed).
resource "aws_sqs_queue" "image_queue" {
  name = "${var.project_name}-queue"

  # Must be >= Router Lambda timeout so in-flight messages stay invisible while it runs
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = {
    Project = var.project_name
  }
}

# Allow S3 to publish notifications to the Standard intake queue
resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.image_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.image_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.raw.arn
          }
        }
      }
    ]
  })
}

