package com.br.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Disposes;
import jakarta.enterprise.inject.Produces;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.s3.S3Client;

import java.net.URI;
import java.util.Optional;

@ApplicationScoped
public class AwsClientProducer {

    @ConfigProperty(name = "app.aws.region", defaultValue = "us-east-1")
    String region;

    /** Set to http://localhost:4566 in dev/LocalStack, absent in production. */
    @ConfigProperty(name = "app.aws.endpoint-override")
    Optional<String> endpointOverride;

    @Produces
    @ApplicationScoped
    public S3Client s3Client() {
        var builder = S3Client.builder()
            .region(Region.of(region))
            .credentialsProvider(DefaultCredentialsProvider.create())
            .httpClient(UrlConnectionHttpClient.create());

        endpointOverride.map(URI::create).ifPresent(uri ->
            builder.endpointOverride(uri).forcePathStyle(true)
        );

        return builder.build();
    }

    @Produces
    @ApplicationScoped
    public DynamoDbClient dynamoDbClient() {
        var builder = DynamoDbClient.builder()
            .region(Region.of(region))
            .credentialsProvider(DefaultCredentialsProvider.create())
            .httpClient(UrlConnectionHttpClient.create());

        endpointOverride.map(URI::create).ifPresent(builder::endpointOverride);

        return builder.build();
    }

    void closeS3(@Disposes S3Client client) { client.close(); }
    void closeDynamoDb(@Disposes DynamoDbClient client) { client.close(); }
}
