import json
import logging
import os
import urllib.parse
import boto3

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

_lambda = boto3.client("lambda")
_PROCESSOR_FUNCTION_NAME = os.environ["PROCESSOR_FUNCTION_NAME"]


def handler(event: dict, context: object) -> None:
    """Routing Lambda: reads S3 event notifications from the Standard SQS intake queue,
    extracts the dealer_id from the S3 key, and invokes the Image Processor Lambda
    directly using Lambda Tenant Isolation Mode (TenantId=dealer_id).

    Lambda routes each invocation to a dealer-specific execution environment,
    preventing cross-tenant state leakage without requiring a FIFO queue.
    """
    for message in event.get("Records", []):
        message_id = message.get("messageId", "<unknown>")
        try:
            _route_message(message["body"])
        except Exception:
            logger.exception("Failed to route SQS message %s", message_id)
            raise


def _route_message(body: str) -> None:
    notification = json.loads(body)
    records = notification.get("Records") or []

    if not records:
        logger.warning("SQS message contains no S3 records — skipping")
        return

    for record in records:
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        dealer_id = key.split("/")[0]

        _lambda.invoke(
            FunctionName=_PROCESSOR_FUNCTION_NAME,
            InvocationType="Event",  # async — fire and forget
            TenantId=dealer_id,
            Payload=json.dumps(record).encode(),
        )
        logger.info("Dispatched s3://%s/%s → processor (tenant '%s')",
                    record["s3"]["bucket"]["name"], key, dealer_id)
