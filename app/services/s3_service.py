import os
import boto3
from botocore.exceptions import ClientError


class S3Service:
    def __init__(self) -> None:
        self._raw_bucket = os.environ["RAW_BUCKET"]
        self._thumbnails_bucket = os.environ["THUMBNAILS_BUCKET"]
        self._client = boto3.client("s3")

    def get_object_metadata(self, key: str) -> dict[str, str]:
        """Returns user-defined metadata for an object in the raw bucket.
        S3 strips the 'x-amz-meta-' prefix and lowercases all keys.
        """
        response = self._client.head_object(Bucket=self._raw_bucket, Key=key)
        return response.get("Metadata", {})

    def thumbnail_exists(self, output_key: str) -> bool:
        """Idempotency gate: returns True if the output key already exists."""
        try:
            self._client.head_object(Bucket=self._thumbnails_bucket, Key=output_key)
            return True
        except ClientError as e:
            if e.response["Error"]["Code"] == "404":
                return False
            raise

    def download_raw(self, key: str) -> bytes:
        response = self._client.get_object(Bucket=self._raw_bucket, Key=key)
        return response["Body"].read()

    def upload_thumbnail(self, key: str, data: bytes, content_type: str) -> None:
        self._client.put_object(
            Bucket=self._thumbnails_bucket,
            Key=key,
            Body=data,
            ContentType=content_type,
        )
