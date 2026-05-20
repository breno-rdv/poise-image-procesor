package com.br.model;

/**
 * Parsed resize specification from S3 object user metadata.
 *
 * Metadata keys (set by the uploader):
 *   x-amz-meta-target-size   → e.g. "800x600" or "800" (auto-height)
 *   x-amz-meta-target-format → e.g. "webp", "jpeg", "png"
 */
public record ResizeSpec(int width, int height, String format) {

    /**
     * @param size   raw value of x-amz-meta-target-size
     * @param format raw value of x-amz-meta-target-format
     */
    public static ResizeSpec from(String size, String format) {
        if (size == null || size.isBlank()) {
            throw new IllegalArgumentException("Missing S3 metadata: x-amz-meta-target-size");
        }
        if (format == null || format.isBlank()) {
            throw new IllegalArgumentException("Missing S3 metadata: x-amz-meta-target-format");
        }

        int width, height;
        String normalised = size.toLowerCase().trim();
        if (normalised.contains("x")) {
            String[] parts = normalised.split("x", 2);
            width  = Integer.parseInt(parts[0].trim());
            height = Integer.parseInt(parts[1].trim());
        } else {
            width  = Integer.parseInt(normalised);
            height = 0; // 0 = keep aspect ratio
        }

        return new ResizeSpec(width, height, format.toLowerCase().trim());
    }

    /** Suffix used in the output S3 key, e.g. "800x600.webp" or "800.webp". */
    public String toSuffix() {
        String sizeStr = height > 0 ? width + "x" + height : String.valueOf(width);
        return sizeStr + "." + format;
    }

    public String contentType() {
        return switch (format) {
            case "webp" -> "image/webp";
            case "png"  -> "image/png";
            case "gif"  -> "image/gif";
            default     -> "image/jpeg";
        };
    }
}
