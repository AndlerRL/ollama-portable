#!/bin/bash
set -e

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

# Resolve relative paths to absolute so the mount + container path work correctly
[[ "$BACKUP_FILE" != /* ]] && BACKUP_FILE="$PROJECT_ROOT/$BACKUP_FILE"

echo "Restoring volumes from $BACKUP_FILE ..."

# Extract directly into volumes using tar (handles symlinks correctly)
docker run --rm \
    -v ollama_storage:/ollama_storage \
    -v open_webui_data:/open_webui_data \
    -v "$PROJECT_ROOT":/backup:ro \
    alpine sh -c "
        rm -rf /ollama_storage/* /open_webui_data/*;
        tar xzf /backup/$(basename "$BACKUP_FILE") -C /;
    "

echo "Done. Restart with: task boot"
