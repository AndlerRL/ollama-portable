#!/bin/bash
# compose.sh — Docker Compose wrapper with hardware detection
# Sources detect.sh to get the right GPU override files, then runs docker compose.

SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/detect.sh"
cd "$PROJECT_ROOT"

exec docker compose $COMPOSE_FILES "$@"
