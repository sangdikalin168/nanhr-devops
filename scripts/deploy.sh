#!/usr/bin/env bash
# Pull a new image tag, restart the stack, verify health; roll back on failure.
# Usage: scripts/deploy.sh <image-tag>
# COMPOSE_PROFILES defaults to "prod" (adds cloudflared + uptime-kuma).
set -euo pipefail

NEW_TAG="${1:?usage: deploy.sh <image-tag>}"
cd "$(dirname "$0")/../deploy"

ENV_FILE=.env
HTTP_PORT="$(grep -E '^HTTP_PORT=' "$ENV_FILE" | cut -d= -f2)"
PREV_TAG="$(grep -E '^IMAGE_TAG=' "$ENV_FILE" | cut -d= -f2)"
export COMPOSE_PROFILES="${COMPOSE_PROFILES-prod}"

compose() { docker compose --env-file "$ENV_FILE" "$@"; }
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

release() {
  set_tag "$1"
  compose pull --quiet &&
    compose up -d --remove-orphans &&
    healthy
}

echo "Deploying $NEW_TAG (previous: $PREV_TAG)"
if release "$NEW_TAG"; then
  echo "Deploy OK: $NEW_TAG"
  docker image prune -f >/dev/null
  exit 0
fi

echo "Deploy of $NEW_TAG failed, rolling back to $PREV_TAG" >&2
if release "$PREV_TAG"; then
  echo "Rollback OK: running $PREV_TAG" >&2
else
  echo "Rollback to $PREV_TAG also failed, manual action needed" >&2
fi
exit 1
