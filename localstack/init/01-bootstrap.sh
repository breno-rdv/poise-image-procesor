#!/bin/sh
set -eu

awslocal s3 mb s3://poise-image-upload-dev || true
awslocal s3 mb s3://poise-image-thumbnail-dev || true

awslocal sqs create-queue --queue-name poise-image-processor-dev-dlq >/dev/null
awslocal sqs create-queue --queue-name poise-image-processor-dev >/dev/null

DLQ_URL=$(awslocal sqs get-queue-url --queue-name poise-image-processor-dev-dlq --query 'QueueUrl' --output text)
DLQ_ARN=$(awslocal sqs get-queue-attributes --queue-url "$DLQ_URL" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
QUEUE_URL=$(awslocal sqs get-queue-url --queue-name poise-image-processor-dev --query 'QueueUrl' --output text)
QUEUE_ARN=$(awslocal sqs get-queue-attributes --queue-url "$QUEUE_URL" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

awslocal sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attributes RedrivePolicy="{\"deadLetterTargetArn\":\"${DLQ_ARN}\",\"maxReceiveCount\":\"3\"}"

awslocal dynamodb create-table \
  --table-name poise-image-processor-dev-metadata \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST >/dev/null || true

cat <<POLICY >/tmp/poise-image-processor-queue-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3SendMessage",
      "Effect": "Allow",
      "Principal": {"Service": "s3.amazonaws.com"},
      "Action": "sqs:SendMessage",
      "Resource": "${QUEUE_ARN}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:s3:::poise-image-upload-dev"
        }
      }
    }
  ]
}
POLICY

awslocal sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attributes Policy="$(tr -d '\n' </tmp/poise-image-processor-queue-policy.json)"

cat <<NOTIFICATION >/tmp/poise-image-processor-notification.json
{
  "QueueConfigurations": [
    {
      "QueueArn": "${QUEUE_ARN}",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
NOTIFICATION

awslocal s3api put-bucket-notification-configuration \
  --bucket poise-image-upload-dev \
  --notification-configuration file:///tmp/poise-image-processor-notification.json
