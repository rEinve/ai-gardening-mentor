#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-ai-gardening-mentor}"
TAG="${2:-latest}"

echo "🌱 Building Podman production container: ${IMAGE_NAME}:${TAG}..."
podman build \
  --file Containerfile \
  --target production \
  --tag "${IMAGE_NAME}:${TAG}" \
  .

echo "✅ Successfully built image: ${IMAGE_NAME}:${TAG}"
echo "👉 Run with: ./scripts/podman-run.sh"
