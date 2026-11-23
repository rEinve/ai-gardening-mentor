#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-4321}"
CONTAINER_NAME="ai-gardening-mentor"
IMAGE_NAME="ai-gardening-mentor:latest"

echo "🌱 Starting ${CONTAINER_NAME} on http://localhost:${PORT}..."
podman run --rm -d \
  --name "${CONTAINER_NAME}" \
  -p "${PORT}:8080" \
  "${IMAGE_NAME}"

echo "✅ Container is up and running!"
echo "👉 Open: http://localhost:${PORT}"
echo "🩺 Health status: http://localhost:${PORT}/healthz"
echo "🛑 Stop with: ./scripts/podman-stop.sh or podman stop ${CONTAINER_NAME}"
