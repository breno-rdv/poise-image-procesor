import json
import logging
from app.services.image_service import ImageService

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

_service = ImageService()


def handler(event: dict, context: object) -> None:
    """Lambda entry point. Invoked directly by the Router Lambda with a single
    S3 event record as the payload (using Lambda Tenant Isolation Mode).

    context.tenant_id is the dealer_id set by the Router — Lambda ensures this
    invocation runs in a dealer-specific execution environment.

    Re-raises on failure so the Router Lambda's retry logic surfaces the error.
    """
    try:
        _service.process(json.dumps({"Records": [event]}))
    except Exception:
        logger.exception("Failed to process image record: %s",
                         event.get("s3", {}).get("object", {}).get("key", "<unknown>"))
        raise
