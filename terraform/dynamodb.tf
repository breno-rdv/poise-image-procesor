resource "aws_dynamodb_table" "image_metadata" {
  name         = "${var.project_name}-metadata"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "imageId"
  range_key = "uploadedAt"

  attribute {
    name = "imageId"
    type = "S"
  }

  attribute {
    name = "uploadedAt"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}
