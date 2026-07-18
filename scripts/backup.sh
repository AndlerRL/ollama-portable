#!/bin/bash

BACKUP_FILE="ollama_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

echo "Backing up ollama_storage volume to $BACKUP_FILE ..."
PROJECT_ROOT="$(dirname "$0")/.."
docker run --rm -v ollama_storage:/data -v "$PROJECT_ROOT":/backup alpine tar czf "/backup/$BACKUP_FILE" -C /data .
echo "Done: $BACKUP_FILE"
