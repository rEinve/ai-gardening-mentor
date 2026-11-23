#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-4321}"
CONTAINER_NAME="ai-gardening-mentor-dev"
IMAGE_NAME="ai-gardening-mentor:dev"

echo "🌱 Building Podman development container image: ${IMAGE_NAME}..."
podman build \
  --file Containerfile \
  --target development \
  --tag "${IMAGE_NAME}" \
  .

echo "🌱 Launching development container with live volume mounts..."
podman run --rm -it \
  --name "${CONTAINER_NAME}" \
  -p "${PORT}:4321" \
  -v "$(pwd):/app:Z" \
  -w /app \
  "${IMAGE_NAME}"
