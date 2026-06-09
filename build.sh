#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="dist"
PACKAGE_DIR="$DIST_DIR/package"
ZIP_PATH="$DIST_DIR/function.zip"

POETRY=$(command -v poetry || echo "${HOME}/.local/bin/poetry")
if [[ ! -x "$POETRY" ]]; then
  echo "ERROR: Poetry not found. Install it with:"
  echo "  curl -sSL https://install.python-poetry.org | python3 -"
  exit 1
fi

PIP=$(command -v pip3 || command -v pip)

echo "==> Cleaning previous build..."
rm -rf "$DIST_DIR"
mkdir -p "$PACKAGE_DIR"

echo "==> Exporting dependencies via Poetry..."
"$POETRY" export --without-hashes --without dev -f requirements.txt -o "$DIST_DIR/requirements.txt"

echo "==> Installing dependencies (linux/x86_64 wheels)..."
"$PIP" install \
  --quiet \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: \
  --target "$PACKAGE_DIR" \
  -r "$DIST_DIR/requirements.txt"

echo "==> Copying application source..."
cp -r app "$PACKAGE_DIR/app"

echo "==> Zipping deployment package..."
cd "$PACKAGE_DIR"
zip -q -r "../../$ZIP_PATH" .
cd - > /dev/null

echo "==> Build complete: $ZIP_PATH ($(du -sh "$ZIP_PATH" | cut -f1))"
