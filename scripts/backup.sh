#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TAG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag|-t)
      TAG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -n "$TAG" ]]; then
  BACKUP_FILE="ollama_backup_${TAG}.tar.gz"
else
  BACKUP_FILE="ollama_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
fi

echo "Backing up volumes: ollama_storage, open_webui_data"

# Use tar directly inside alpine to handle symlinks correctly
# (huggingface cache uses symlinks for blob storage)
docker run --rm \
  -v ollama_storage:/ollama_storage:ro \
  -v open_webui_data:/open_webui_data:ro \
  -v "$PROJECT_ROOT":/backup \
  alpine tar czf "/backup/$BACKUP_FILE" -C / ollama_storage open_webui_data

echo "Done: $PROJECT_ROOT/$BACKUP_FILE"
