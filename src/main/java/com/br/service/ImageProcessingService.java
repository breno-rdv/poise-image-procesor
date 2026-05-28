package com.br.service;

import com.br.model.ResizeSpec;
import com.br.model.S3EventNotification;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import net.coobird.thumbnailator.Thumbnails;
import org.jboss.logging.Logger;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

@ApplicationScoped
public class ImageProcessingService {

    private static final Logger LOG = Logger.getLogger(ImageProcessingService.class);

    @Inject ObjectMapper objectMapper;
    @Inject S3Service s3Service;
    @Inject DynamoDbService dynamoDbService;

    /**
     * Entry point called for each SQS message body (an S3 event notification JSON).
     * Idempotent: if the output key already exists in S3, the message is skipped.
     *
     * Expected S3 key format : {dealerId}/{carroId}/{filename}
     * Expected S3 metadata   : x-amz-meta-target-size   → e.g. "800x600"
     *                          x-amz-meta-target-format  → e.g. "webp"
     */
    public void process(String sqsMessageBody) throws Exception {
        S3EventNotification notification =
            objectMapper.readValue(sqsMessageBody, S3EventNotification.class);

        if (notification.getRecords() == null || notification.getRecords().isEmpty()) {
            LOG.warn("SQS message contains no S3 records — skipping");
            return;
        }

        for (S3EventNotification.Record record : notification.getRecords()) {
            processRecord(record);
        }
    }

    private void processRecord(S3EventNotification.Record record) throws Exception {
        // S3 event notifications URL-encode the object key
        String sourceKey = URLDecoder.decode(
            record.getS3().getObject().getKey(), StandardCharsets.UTF_8);

        // Parse hierarchy from key: {dealerId}/{carroId}/{filename}
        String[] segments = sourceKey.split("/");
        if (segments.length < 3) {
            LOG.errorf("Invalid S3 key '%s' — expected dealerId/carroId/filename", sourceKey);
            return;
        }
        String dealerId  = segments[0];
        String carroId   = segments[1];
        String filename  = segments[segments.length - 1]; // last segment

        // Read resize spec from object user metadata
        Map<String, String> metadata = s3Service.getObjectMetadata(sourceKey);
        String sizeStr = metadata.get("target-size");   // x-amz-meta-target-size  → target-size
        String format  = metadata.get("target-format"); // x-amz-meta-target-format → target-format

        ResizeSpec spec = ResizeSpec.from(sizeStr, format);

        // Deterministic output key guarantees idempotency
        String filenameBase = filename.contains(".")
            ? filename.substring(0, filename.lastIndexOf('.'))
            : filename;
        String outputKey = String.format("%s/%s/%s/%s",
            dealerId, carroId, filenameBase, spec.toSuffix());

        // Idempotency gate: skip if this exact output already exists
        if (s3Service.thumbnailExists(outputKey)) {
            LOG.infof("Output already exists, skipping idempotently: %s", outputKey);
            return;
        }

        // Download → resize → upload
        byte[] rawBytes     = s3Service.downloadRaw(sourceKey);
        byte[] resizedBytes = resize(rawBytes, spec);
        s3Service.uploadThumbnail(outputKey, resizedBytes, spec.contentType());

        // Persist metadata (idempotent: same outputKey overwrites same DynamoDB item)
        dynamoDbService.saveProcessedRecord(outputKey, dealerId, carroId, sourceKey, sizeStr, format);

        LOG.infof("Processed %s → %s [%s]", sourceKey, outputKey, spec.toSuffix());
    }

    private byte[] resize(byte[] input, ResizeSpec spec) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();

        var builder = Thumbnails.of(new ByteArrayInputStream(input))
            .outputFormat(spec.format());

        if (spec.height() > 0) {
            builder.size(spec.width(), spec.height()).keepAspectRatio(false);
        } else {
            builder.width(spec.width()).keepAspectRatio(true);
        }

        builder.toOutputStream(out);
        return out.toByteArray();
    }
}
