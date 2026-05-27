# poise-image-processor
Image processor for generating vehicle thumbnails.

## Architecture

```
Upload image to S3 (raw bucket)
  key:      {dealerId}/{carroId}/{filename}
  metadata: x-amz-meta-target-size=800x600
            x-amz-meta-target-format=webp
        |
        v
S3 ObjectCreated event -> SQS queue
        |
        v
Lambda (SQSLambdaHandler)
  1. Parse S3 key  -> dealerId / carroId / filename
  2. Read metadata -> target-size / target-format
  3. Check S3 for output key (idempotency gate)
  4. Download raw image
  5. Resize with Thumbnailator
  6. Upload to thumbnails bucket
  7. Persist record to DynamoDB
        |
        v
Thumbnails bucket: {dealerId}/{carroId}/{filename-base}/{size}.{format}
DynamoDB: audit record per processed variant
```

### Message properties

| S3 object attribute | Value | Example |
|---|---|---|
| S3 key | `{dealerId}/{carroId}/{filename}` | `dealer42/carro99/front.jpg` |
| User metadata | `x-amz-meta-target-size` | `800x600` or `800` (auto-height) |
| User metadata | `x-amz-meta-target-format` | `webp` · `jpeg` · `png` |

### Idempotency

The output S3 key is **deterministic**: `{dealerId}/{carroId}/{filename-base}/{size}.{format}`.
Before any processing the Lambda does a `HeadObject` on that key. If it already exists
the message is silently skipped — re-delivering the same SQS message is safe.

---

## Testing locally with LocalStack

### Prerequisites

| Tool | Install |
|---|---|
| Docker | https://docs.docker.com/get-docker/ |
| LocalStack CLI | `pip install localstack` |
| Terraform >= 1.6 | https://developer.hashicorp.com/terraform/install |
| AWS CLI v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Java 21+ & Maven | included via `./mvnw` wrapper |

### 0 — Configure a LocalStack AWS profile (one-time)

LocalStack doesn't validate credentials, but the AWS CLI requires *something* to be set.
Add a dummy profile once:

```bash
aws configure --profile localstack
# AWS Access Key ID:     test
# AWS Secret Access Key: test
# Default region name:   us-east-1
# Default output format: json
```

All subsequent `aws` commands in this guide use `--profile localstack`.

### 1 — Start LocalStack

```bash
localstack start -d        # -d runs it in the background
localstack status services # wait until all services show "running"
```

### 2 — Build the Lambda ZIP

Choose one of the two options below. They differ in build time and runtime parity with production.

#### Option A — JVM build (fast iteration, no Docker required)

```bash
./mvnw package -DskipTests
# produces: target/function.zip (class files + JARs, no bootstrap binary)
```

Uses `lambda_runtime = "java21"` (set in `localstack.tfvars`). Builds in seconds.

#### Option B — Native build (prod-parity, Linux binary via Docker)

Builds a Linux-native `bootstrap` binary inside a Docker container using GraalVM from GitHub Container Registry — **no quay.io required**.

```bash
./build-native-linux.sh              # linux/arm64  (default, matches Lambda arm64)
./build-native-linux.sh linux/amd64  # if using x86_64 Lambda
# produces: target/function.zip with a Linux ELF 'bootstrap' binary
```

Uses the default `lambda_runtime = "provided.al2023"`. Before deploying, comment out or
remove the `lambda_runtime` override from `localstack.tfvars`:

```hcl
# lambda_runtime = "java21"   ← comment out for native build
```

> **Why two runtimes?**
> A JVM build contains only class files — Lambda needs `java21` to run them.
> A native build contains a `bootstrap` binary — Lambda uses the custom `provided.al2023`
> runtime to execute it directly (no JVM). Native cold-starts in milliseconds vs seconds.

### 3 — Deploy infrastructure with Terraform

```bash
cd terraform
terraform init
terraform apply -var-file="localstack.tfvars" -auto-approve
cd ..
```

This creates the S3 buckets, SQS queues, DynamoDB table, and Lambda — all inside LocalStack.

### 4 — Upload a test image

The key must follow `{dealerId}/{carroId}/{filename}`.
Pass the resize spec as S3 user metadata.

```bash
# Example: dealer42 / carro99 / front.jpg  ->  resize to 800x600 webp
aws --endpoint-url=http://localhost:4566 --profile localstack s3 cp /path/to/front.jpg \
  s3://poise-image-processor-raw/dealer42/carro99/front.jpg \
  --metadata "target-size=800x600,target-format=webp"
```

> **Different sizes for different platform contexts:**
>
> ```bash
> # Listing card thumbnail
> aws --endpoint-url=http://localhost:4566 --profile localstack s3 cp /path/to/front.jpg \
>   s3://poise-image-processor-raw/dealer42/carro99/front.jpg \
>   --metadata "target-size=400x300,target-format=webp"
>
> # Detail page hero (width only, height auto-proportional)
> aws --endpoint-url=http://localhost:4566 --profile localstack s3 cp /path/to/front.jpg \
>   s3://poise-image-processor-raw/dealer42/carro99/front.jpg \
>   --metadata "target-size=1200,target-format=jpeg"
> ```

### 5 — Watch Lambda logs

```bash
aws --endpoint-url=http://localhost:4566 --profile localstack logs tail \
  /aws/lambda/poise-image-processor --follow
```

### 6 — Verify the output

**Check the thumbnails bucket:**

```bash
aws --endpoint-url=http://localhost:4566 --profile localstack s3 ls \
  s3://poise-image-processor-thumbnails/dealer42/carro99/front/ --recursive
# Expected: dealer42/carro99/front/800x600.webp
```

**Check the DynamoDB record:**

```bash
aws --endpoint-url=http://localhost:4566 --profile localstack dynamodb get-item \
  --table-name poise-image-processor-metadata \
  --key '{"imageId": {"S": "dealer42/carro99/front/800x600.webp"}}'
```

Expected response:

```json
{
    "Item": {
        "imageId":     {"S": "dealer42/carro99/front/800x600.webp"},
        "dealerId":    {"S": "dealer42"},
        "carroId":     {"S": "carro99"},
        "sourceKey":   {"S": "dealer42/carro99/front.jpg"},
        "size":        {"S": "800x600"},
        "format":      {"S": "webp"},
        "status":      {"S": "PROCESSED"},
        "processedAt": {"S": "2026-05-20T..."}
    }
}
```

### 7 — Verify idempotency

Re-upload the exact same file. The Lambda should log `"Output already exists, skipping idempotently"` and return without re-processing or writing to DynamoDB.

```bash
aws --endpoint-url=http://localhost:4566 --profile localstack s3 cp /path/to/front.jpg \
  s3://poise-image-processor-raw/dealer42/carro99/front.jpg \
  --metadata "target-size=800x600,target-format=webp"

aws --endpoint-url=http://localhost:4566 --profile localstack logs tail \
  /aws/lambda/poise-image-processor
# Look for: "Output already exists, skipping idempotently: dealer42/carro99/front/800x600.webp"
```

### 8 — Inspect the DLQ on failure

If a message fails `maxReceiveCount` times (default: 3) it lands in the dead-letter queue:

```bash
aws --endpoint-url=http://localhost:4566 --profile localstack sqs receive-message \
  --queue-url http://localhost:4566/000000000000/poise-image-processor-dlq
```

### Teardown

```bash
cd terraform && terraform destroy -var-file="localstack.tfvars" -auto-approve && cd ..
localstack stop
```

---

## Building for production (native executable)

```bash
./build-native-linux.sh
```

Produces `target/function.zip` with a Linux ELF `bootstrap` binary for the `provided.al2023` runtime.

## Deploying to AWS

```bash
cd terraform
terraform init
terraform apply   # uses default variables (no localstack.tfvars)
```

---

## Lessons learned

**Patterns:** Queue-Based Load Leveling · Competing Consumers · Pipes and Filters

**Services:** S3 · Lambda · SQS · DynamoDB · CloudWatch

**Concepts:** async processing · retries · DLQ · idempotency · event-driven architecture

**Java:** SQS consumer · DynamoDB SDK v2 · structured logging · Quarkus native image · Thumbnailator
