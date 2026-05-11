import json
import logging
import os
from io import BytesIO
from urllib.parse import unquote_plus

LOGGER = logging.getLogger()
LOGGER.setLevel(os.getenv("LOG_LEVEL", "INFO"))


def parse_s3_records(event):
    for sqs_record in event.get("Records", []):
        body = sqs_record.get("body") or "{}"
        payload = json.loads(body)
        for s3_record in payload.get("Records", []):
            if s3_record.get("eventSource") == "aws:s3":
                yield s3_record


def build_thumbnail_key(source_key):
    return f"thumbnails/{source_key.lstrip('/')}"


def build_item(source_bucket, source_key, etag, thumbnail_bucket, thumbnail_key):
    return {
        "id": f"{source_bucket}:{source_key}:{etag or 'unknown'}",
        "sourceBucket": source_bucket,
        "sourceKey": source_key,
        "thumbnailBucket": thumbnail_bucket,
        "thumbnailKey": thumbnail_key,
    }


def create_thumbnail(image_bytes, size):
    try:
        from PIL import Image
    except ImportError as exc:  # pragma: no cover - exercised only in deployed runtime
        raise RuntimeError("Pillow must be provided through the Lambda layer") from exc

    image = Image.open(BytesIO(image_bytes))
    image.thumbnail(size)

    buffer = BytesIO()
    output_format = image.format or "JPEG"
    image.save(buffer, format=output_format)
    buffer.seek(0)
    return buffer.read(), output_format


def process_record(s3_record, s3_client, dynamodb_client, thumbnail_bucket, metadata_table, thumbnail_size):
    source_bucket = s3_record["s3"]["bucket"]["name"]
    source_key = unquote_plus(s3_record["s3"]["object"]["key"])
    etag = s3_record["s3"]["object"].get("eTag")
    thumbnail_key = build_thumbnail_key(source_key)
    item = build_item(source_bucket, source_key, etag, thumbnail_bucket, thumbnail_key)

    try:
        dynamodb_client.put_item(
            TableName=metadata_table,
            Item={key: {"S": value} for key, value in item.items()},
            ConditionExpression="attribute_not_exists(id)",
        )
    except dynamodb_client.exceptions.ConditionalCheckFailedException:
        LOGGER.info(json.dumps({"message": "Skipping duplicate image event", "id": item["id"]}))
        return {"status": "duplicate", "id": item["id"]}

    image_object = s3_client.get_object(Bucket=source_bucket, Key=source_key)
    thumbnail_bytes, output_format = create_thumbnail(image_object["Body"].read(), thumbnail_size)

    s3_client.put_object(
        Bucket=thumbnail_bucket,
        Key=thumbnail_key,
        Body=thumbnail_bytes,
        ContentType=f"image/{output_format.lower()}",
    )

    LOGGER.info(json.dumps({
        "message": "Thumbnail created",
        "source_bucket": source_bucket,
        "source_key": source_key,
        "thumbnail_bucket": thumbnail_bucket,
        "thumbnail_key": thumbnail_key,
    }))
    return {"status": "processed", "id": item["id"]}


def lambda_handler(event, _context):
    import boto3

    s3_client = boto3.client("s3")
    dynamodb_client = boto3.client("dynamodb")

    thumbnail_bucket = os.environ["THUMBNAIL_BUCKET"]
    metadata_table = os.environ["METADATA_TABLE"]
    thumbnail_size = (
        int(os.getenv("THUMBNAIL_WIDTH", "256")),
        int(os.getenv("THUMBNAIL_HEIGHT", "256")),
    )

    results = [
        process_record(
            record,
            s3_client=s3_client,
            dynamodb_client=dynamodb_client,
            thumbnail_bucket=thumbnail_bucket,
            metadata_table=metadata_table,
            thumbnail_size=thumbnail_size,
        )
        for record in parse_s3_records(event)
    ]

    return {"processed": len(results), "results": results}
