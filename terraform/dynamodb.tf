resource "aws_dynamodb_table" "image_metadata" {
  name         = "${var.project_name}-metadata"
  billing_mode = "PAY_PER_REQUEST"

  # imageId = deterministic output S3 key: {dealerId}/{carroId}/{filename}/{size}.{format}
  hash_key = "imageId"

  attribute {
    name = "imageId"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}
