#!/usr/bin/env bash
# Build a Linux-native Lambda zip using a local Docker build.
# Avoids pulling the Quarkus builder image from quay.io.
#
# Usage:
#   ./build-native-linux.sh              # linux/arm64  (default, matches Lambda arm64)
#   ./build-native-linux.sh linux/amd64  # linux/amd64  (for x86_64 Lambda)

set -euo pipefail

PLATFORM=${1:-linux/arm64}
IMAGE=poise-native-builder:latest

echo "==> Building Linux native image [platform: $PLATFORM]"

docker build \
  --platform "$PLATFORM" \
  -t "$IMAGE" \
  -f Dockerfile.native-linux \
  .

echo "==> Extracting target/function.zip"
CONTAINER=$(docker create --platform "$PLATFORM" "$IMAGE")
docker cp "$CONTAINER":/build/target/function.zip target/function.zip
docker rm "$CONTAINER" > /dev/null

echo "==> Done: target/function.zip (Linux native, $PLATFORM)"
