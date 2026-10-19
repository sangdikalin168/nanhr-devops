#!/usr/bin/env bash
# Pull a new image tag, restart the stack, verify health; roll back on failure.
# Usage: scripts/deploy.sh <image-tag>
set -euo pipefail

NEW_TAG="${1:?usage: deploy.sh <image-tag>}"
cd "$(dirname "$0")/../deploy"

ENV_FILE=.env
HTTP_PORT="$(grep -E '^HTTP_PORT=' "$ENV_FILE" | cut -d= -f2)"
COMPOSE="docker compose --env-file $ENV_FILE --profile prod"
PREV_TAG="$(grep -E '^IMAGE_TAG=' "$ENV_FILE" | cut -d= -f2)"

set_tag() { sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$1/" "$ENV_FILE"; }

healthy() {
  for _ in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:${HTTP_PORT:-8080}/api/health" >/dev/null &&
       curl -fsS "http://127.0.0.1:${HTTP_PORT:-8080}/py/health" >/dev/null; then
      return 0
    fi
    sleep 3
  done
  return 1
}

echo "Deploying $NEW_TAG (previous: $PREV_TAG)"
set_tag "$NEW_TAG"
$COMPOSE pull
$COMPOSE up -d --remove-orphans

if healthy; then
  echo "Deploy OK: $NEW_TAG"
  docker image prune -f >/dev/null
else
  echo "Health check failed, rolling back to $PREV_TAG" >&2
  set_tag "$PREV_TAG"
  $COMPOSE pull
  $COMPOSE up -d --remove-orphans
  exit 1
fi
