package com.br.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;

import java.time.Instant;
import java.util.Map;

@ApplicationScoped
public class DynamoDbService {

    @Inject
    DynamoDbClient dynamoDb;

    @ConfigProperty(name = "app.dynamodb-table")
    String tableName;

    /**
     * Persists a processed image record. The imageId (hash key) is the
     * deterministic output S3 key, making this call naturally idempotent —
     * re-running with the same inputs simply overwrites the same item.
     */
    public void saveProcessedRecord(
            String outputKey,
            String dealerId,
            String carroId,
            String sourceKey,
            String size,
            String format) {

        dynamoDb.putItem(PutItemRequest.builder()
            .tableName(tableName)
            .item(Map.of(
                "imageId",    AttributeValue.fromS(outputKey),
                "dealerId",   AttributeValue.fromS(dealerId),
                "carroId",    AttributeValue.fromS(carroId),
                "sourceKey",  AttributeValue.fromS(sourceKey),
                "size",       AttributeValue.fromS(size),
                "format",     AttributeValue.fromS(format),
                "status",     AttributeValue.fromS("PROCESSED"),
                "processedAt", AttributeValue.fromS(Instant.now().toString())
            ))
            .build());
    }
}
