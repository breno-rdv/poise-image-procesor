from __future__ import annotations
from dataclasses import dataclass


@dataclass(frozen=True)
class ResizeSpec:
    width: int
    height: int   # 0 means keep aspect ratio
    format: str   # lower-cased, e.g. "webp", "jpeg", "png"

    @classmethod
    def from_metadata(cls, size: str | None, fmt: str | None) -> "ResizeSpec":
        if not size or not size.strip():
            raise ValueError("Missing S3 metadata: x-amz-meta-target-size")
        if not fmt or not fmt.strip():
            raise ValueError("Missing S3 metadata: x-amz-meta-target-format")

        normalised = size.lower().strip()
        if "x" in normalised:
            w_str, h_str = normalised.split("x", 1)
            width, height = int(w_str.strip()), int(h_str.strip())
        else:
            width, height = int(normalised), 0

        return cls(width=width, height=height, format=fmt.lower().strip())

    def to_suffix(self) -> str:
        size_str = f"{self.width}x{self.height}" if self.height > 0 else str(self.width)
        return f"{size_str}.{self.format}"

    def content_type(self) -> str:
        return {
            "webp": "image/webp",
            "png":  "image/png",
            "gif":  "image/gif",
        }.get(self.format, "image/jpeg")
