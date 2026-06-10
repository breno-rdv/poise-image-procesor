import os
from datetime import datetime, timezone
import boto3


class DynamoDbService:
    def __init__(self) -> None:
        self._table_name = os.environ["DYNAMODB_TABLE"]
        self._client = boto3.client("dynamodb")

    def save_processed_record(
        self,
        output_key: str,
        dealer_id: str,
        vehicle_id: str,
        source_key: str,
        size: str,
        fmt: str,
    ) -> None:
        """Persists a processed image record.
        The imageId (hash key) is the deterministic output S3 key,
        making this call naturally idempotent — same inputs overwrites the same item.
        """
        self._client.put_item(
            TableName=self._table_name,
            Item={
                "imageId":     {"S": output_key},
                "dealerId":    {"S": dealer_id},
                "vehicleId":     {"S": vehicle_id},
                "sourceKey":   {"S": source_key},
                "size":        {"S": size},
                "format":      {"S": fmt},
                "status":      {"S": "PROCESSED"},
                "processedAt": {"S": datetime.now(timezone.utc).isoformat()},
            },
        )
