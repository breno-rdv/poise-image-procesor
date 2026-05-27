package com.br.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import io.quarkus.runtime.annotations.RegisterForReflection;
import java.util.List;

/**
 * Subset of the S3 event notification JSON that S3 publishes to SQS
 * when a new object is created in the raw bucket.
 */
@RegisterForReflection   // registers this class + all nested static classes for GraalVM reflection
@JsonIgnoreProperties(ignoreUnknown = true)
public class S3EventNotification {

    private List<Record> Records;

    public List<Record> getRecords() { return Records; }
    public void setRecords(List<Record> records) { this.Records = records; }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Record {
        private S3Entity s3;
        public S3Entity getS3() { return s3; }
        public void setS3(S3Entity s3) { this.s3 = s3; }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class S3Entity {
        private BucketEntity bucket;
        private ObjectEntity object;
        public BucketEntity getBucket() { return bucket; }
        public void setBucket(BucketEntity bucket) { this.bucket = bucket; }
        public ObjectEntity getObject() { return object; }
        public void setObject(ObjectEntity object) { this.object = object; }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class BucketEntity {
        private String name;
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class ObjectEntity {
        private String key;
        public String getKey() { return key; }
        public void setKey(String key) { this.key = key; }
    }
}
