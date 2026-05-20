package com.br.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import java.util.Map;

@ApplicationScoped
public class S3Service {

    @Inject
    S3Client s3;

    @ConfigProperty(name = "app.raw-bucket")
    String rawBucket;

    @ConfigProperty(name = "app.thumbnails-bucket")
    String thumbnailsBucket;

    /**
     * Returns the user-defined metadata of an object in the raw bucket.
     * S3 strips the "x-amz-meta-" prefix; keys are lowercased.
     * e.g. x-amz-meta-target-size → "target-size"
     */
    public Map<String, String> getObjectMetadata(String key) {
        HeadObjectResponse response = s3.headObject(
            HeadObjectRequest.builder()
                .bucket(rawBucket)
                .key(key)
                .build()
        );
        return response.metadata();
    }

    /**
     * Returns true if the output key already exists in the thumbnails bucket.
     * Used as the idempotency gate before processing.
     */
    public boolean thumbnailExists(String outputKey) {
        try {
            s3.headObject(HeadObjectRequest.builder()
                .bucket(thumbnailsBucket)
                .key(outputKey)
                .build());
            return true;
        } catch (NoSuchKeyException e) {
            return false;
        }
    }

    public byte[] downloadRaw(String key) {
        return s3.getObjectAsBytes(
            GetObjectRequest.builder()
                .bucket(rawBucket)
                .key(key)
                .build()
        ).asByteArray();
    }

    public void uploadThumbnail(String key, byte[] data, String contentType) {
        s3.putObject(
            PutObjectRequest.builder()
                .bucket(thumbnailsBucket)
                .key(key)
                .contentType(contentType)
                .build(),
            RequestBody.fromBytes(data)
        );
    }
}
