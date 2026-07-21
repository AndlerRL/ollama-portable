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

echo "Restoring volumes from $BACKUP_FILE ..."

TMPDIR=$(mktemp -d)
tar xzf "$BACKUP_FILE" -C "$TMPDIR"

if [ -d "$TMPDIR/ollama_storage" ]; then
    docker run --rm -v ollama_storage:/data -v "$TMPDIR":/backup alpine sh -c "rm -rf /data/* && cp -a /backup/ollama_storage/. /data/"
fi

if [ -d "$TMPDIR/open_webui_data" ]; then
    docker run --rm -v open_webui_data:/data -v "$TMPDIR":/backup alpine sh -c "rm -rf /data/* && cp -a /backup/open_webui_data/. /data/"
fi

rm -rf "$TMPDIR"

echo "Done. Restart with: task boot"
