#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: restore.sh <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -1 "$PROJECT_ROOT"/ollama_backup_*.tar.gz 2>/dev/null || echo "  (none found)"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "File not found: $BACKUP_FILE"
    exit 1
fi

echo "Restoring ollama_storage volume from $BACKUP_FILE ..."
docker run --rm -v ollama_storage:/data -v "$PROJECT_ROOT":/backup alpine sh -c "rm -rf /data/* && tar xzf \"/backup/$BACKUP_FILE\" -C /data"
echo "Done. Restart the server with: task boot"
