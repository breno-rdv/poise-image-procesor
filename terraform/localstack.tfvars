# Override values for LocalStack local development
# Usage: terraform apply -var-file="localstack.tfvars"

localstack      = true
aws_region      = "us-east-1"
lambda_zip_path = "../target/function.zip"

# JVM build (./mvnw package -DskipTests) produces a fat zip with class files — no bootstrap
# binary — so it requires the java21 managed runtime, not the custom provided.al2023 runtime.
# Comment this line out (or remove it) when deploying a native build for prod-parity.
# lambda_runtime  = "java21"
