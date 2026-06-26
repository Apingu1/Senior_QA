#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

COMPOSE_FILE="infra/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or is not available in this terminal."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is not available. Try updating Docker or enabling the Docker Compose plugin."
  exit 1
fi

if [ ! -f ".env" ]; then
  echo ".env not found. Creating it from example.env."
  cp example.env .env
  echo "Created .env. Review it later if you need to change admin settings or AI configuration."
fi

echo "Starting Senior QA without deleting the database volume..."
echo "Using compose file: $COMPOSE_FILE"
echo ""

docker compose -f "$COMPOSE_FILE" up --build
