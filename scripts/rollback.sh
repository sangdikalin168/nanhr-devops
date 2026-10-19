#!/usr/bin/env bash
# Redeploy any earlier image tag from GHCR, e.g. scripts/rollback.sh sha-1a2b3c4
set -euo pipefail
exec "$(dirname "$0")/deploy.sh" "${1:?usage: rollback.sh <image-tag>}"
