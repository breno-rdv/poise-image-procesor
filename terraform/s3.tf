# Bucket that receives original (raw) image uploads
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-raw"

  tags = {
    Name    = "${var.project_name}-raw"
    Project = var.project_name
  }
}

# Bucket that stores generated thumbnails
resource "aws_s3_bucket" "thumbnails" {
  bucket = "${var.project_name}-thumbnails"

  tags = {
    Name    = "${var.project_name}-thumbnails"
    Project = var.project_name
  }
}

# Fire an SQS message for every new object in the raw bucket
resource "aws_s3_bucket_notification" "raw_upload" {
  bucket = aws_s3_bucket.raw.id

  queue {
    queue_arn = aws_sqs_queue.image_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }

  # Queue policy must exist before the notification can be created
  depends_on = [aws_sqs_queue_policy.allow_s3]
}