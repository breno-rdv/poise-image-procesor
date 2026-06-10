import io
import logging
import urllib.parse
from PIL import Image

from app.models.resize_spec import ResizeSpec
from app.services.s3_service import S3Service
from app.services.dynamodb_service import DynamoDbService

logger = logging.getLogger(__name__)


class ImageService:
    def __init__(self) -> None:
        self._s3 = S3Service()
        self._dynamo = DynamoDbService()

    def process(self, sqs_message_body: str) -> None:
        """Entry point called for each SQS message body (an S3 event notification JSON).
        Idempotent: if the output key already exists in S3, the message is skipped.

        Expected S3 key format : {dealerId}/{vehicleId}/{filename}
        Expected S3 metadata   : target-size   → e.g. "800x600"
                                 target-format  → e.g. "webp"
        """
        import json
        notification = json.loads(sqs_message_body)
        records = notification.get("Records") or []

        if not records:
            logger.warning("SQS message contains no S3 records — skipping")
            return

        for record in records:
            self._process_record(record)

    def _process_record(self, record: dict) -> None:
        # S3 event notifications URL-encode the object key
        source_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        # Parse hierarchy from key: {dealerId}/{vehicleId}/{filename}
        segments = source_key.split("/")
        if len(segments) < 3:
            logger.error("Invalid S3 key '%s' — expected dealerId/vehicleId/filename", source_key)
            return

        dealer_id = segments[0]
        vehicle_id  = segments[1]
        filename  = segments[-1]

        metadata = self._s3.get_object_metadata(source_key)
        spec = ResizeSpec.from_metadata(
            metadata.get("target-size"),
            metadata.get("target-format"),
        )

        filename_base = filename.rsplit(".", 1)[0] if "." in filename else filename
        output_key = f"{dealer_id}/{vehicle_id}/{filename_base}/{spec.to_suffix()}"

        if self._s3.thumbnail_exists(output_key):
            logger.info("Output already exists, skipping idempotently: %s", output_key)
            return

        raw_bytes     = self._s3.download_raw(source_key)
        resized_bytes = self._resize(raw_bytes, spec)
        self._s3.upload_thumbnail(output_key, resized_bytes, spec.content_type())

        self._dynamo.save_processed_record(
            output_key, dealer_id, vehicle_id, source_key,
            metadata.get("target-size", ""), spec.format,
        )

        logger.info("Processed %s → %s [%s]", source_key, output_key, spec.to_suffix())

    def _resize(self, data: bytes, spec: ResizeSpec) -> bytes:
        # Pillow supports WebP natively (libwebp is bundled in the Linux wheel).
        img = Image.open(io.BytesIO(data))

        # Preserve transparency for formats that support it; convert others to RGB.
        pil_format = spec.format.upper()
        if pil_format == "JPEG" and img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        if spec.height > 0:
            img = img.resize((spec.width, spec.height), Image.LANCZOS)
        else:
            ratio  = spec.width / img.width
            height = round(img.height * ratio)
            img    = img.resize((spec.width, height), Image.LANCZOS)

        out = io.BytesIO()
        img.save(out, format=pil_format)
        return out.getvalue()
