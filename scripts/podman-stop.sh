#!/usr/bin/env bash
set -euo pipefail

echo "🛑 Stopping AI Gardening Mentor containers..."
podman stop ai-gardening-mentor 2>/dev/null && echo "✅ Stopped ai-gardening-mentor" || true
podman stop ai-gardening-mentor-dev 2>/dev/null && echo "✅ Stopped ai-gardening-mentor-dev" || true
