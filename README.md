# poise-image-processor

Boilerplate for an event-driven image processor that uses S3, SQS, Lambda, DynamoDB, and CloudWatch.

## Flow

1. Upload an image to the upload bucket.
2. S3 publishes an `ObjectCreated` event to SQS.
3. The Lambda worker consumes the queue message.
4. The worker creates a thumbnail with Pillow.
5. Thumbnail metadata is stored in DynamoDB.

## Repository layout

- `src/functions/image_processor/app.py`: Python Lambda worker.
- `src/layers/pillow/requirements.txt`: Pillow Lambda layer definition.
- `localstack/init/01-bootstrap.sh`: local infrastructure bootstrap for LocalStack.
- `terraform/`: AWS infrastructure definitions.
- `.github/workflows/terraform.yml`: GitHub Actions workflow for Terraform deployment.

## Local environment with LocalStack

Start LocalStack:

```bash
docker compose up -d
```

The bootstrap script creates:

- `poise-image-upload-dev`
- `poise-image-thumbnail-dev`
- `poise-image-processor-dev`
- `poise-image-processor-dev-dlq`
- `poise-image-processor-dev-metadata`

Build the deployable artifacts locally:

```bash
mkdir -p dist build/pillow/python
python -m pip install -r src/layers/pillow/requirements.txt -t build/pillow/python
(cd build/pillow && zip -r ../../dist/pillow-layer.zip python)
(cd src/functions/image_processor && zip -r ../../../dist/image-processor.zip .)
```

## AWS deployment with Terraform

The Terraform stack provisions:

- S3 upload bucket
- S3 thumbnail bucket
- SQS processing queue and DLQ
- S3 notification to SQS
- Lambda worker and Pillow layer
- DynamoDB metadata table
- CloudWatch log group
- IAM permissions

Deploy manually:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan \
  -var="lambda_zip_path=../dist/image-processor.zip" \
  -var="pillow_layer_zip=../dist/pillow-layer.zip"
terraform -chdir=terraform apply \
  -var="lambda_zip_path=../dist/image-processor.zip" \
  -var="pillow_layer_zip=../dist/pillow-layer.zip"
```

## GitHub Actions

The workflow in `.github/workflows/terraform.yml`:

1. builds the Lambda package
2. builds the Pillow layer
3. authenticates to AWS using OIDC
4. runs `terraform fmt`, `init`, `validate`, `plan`, and `apply`

Configure these repository settings before running the workflow:

- `secrets.AWS_ROLE_TO_ASSUME`
- `vars.AWS_REGION`
