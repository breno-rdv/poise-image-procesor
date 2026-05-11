import importlib.util
import pathlib
import unittest

MODULE_PATH = pathlib.Path(__file__).resolve().parents[1] / "src/functions/image_processor/app.py"
SPEC = importlib.util.spec_from_file_location("image_processor_app", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ParseS3RecordsTests(unittest.TestCase):
    def test_parse_s3_records_reads_s3_event_from_sqs_body(self):
        event = {
            "Records": [
                {
                    "body": '{"Records":[{"eventSource":"aws:s3","s3":{"bucket":{"name":"uploads"},"object":{"key":"incoming/car.jpg","eTag":"123"}}}]}'
                }
            ]
        }

        records = list(MODULE.parse_s3_records(event))

        self.assertEqual(1, len(records))
        self.assertEqual("uploads", records[0]["s3"]["bucket"]["name"])
        self.assertEqual("incoming/car.jpg", records[0]["s3"]["object"]["key"])


class BuildThumbnailKeyTests(unittest.TestCase):
    def test_build_thumbnail_key_preserves_the_source_path_under_the_thumbnail_prefix(self):
        self.assertEqual(
            "thumbnails/incoming/vehicles/car.jpg",
            MODULE.build_thumbnail_key("incoming/vehicles/car.jpg"),
        )


class BuildItemTests(unittest.TestCase):
    def test_build_item_creates_stable_idempotency_key(self):
        item = MODULE.build_item("uploads", "incoming/car.jpg", "etag-1", "thumbnails", "thumbnails/car.jpg")

        self.assertEqual("uploads:incoming/car.jpg:etag-1", item["id"])
        self.assertEqual("thumbnails/car.jpg", item["thumbnailKey"])


if __name__ == "__main__":
    unittest.main()
