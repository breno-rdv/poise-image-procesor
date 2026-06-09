import logging
from app.services.image_service import ImageService

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

_service = ImageService()


def handler(event: dict, context: object) -> None:
    """Lambda entry point. Receives an SQS event containing S3 event notification records.
    Re-raises on failure so SQS retries the message (up to maxReceiveCount, then DLQ).
    """
    for message in event.get("Records", []):
        message_id = message.get("messageId", "<unknown>")
        try:
            _service.process(message["body"])
        except Exception:
            logger.exception("Failed to process SQS message %s", message_id)
            raise
