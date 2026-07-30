#!/bin/bash

set -euo pipefail

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

BACKUP_DIR="$(cd "$(dirname "$BACKUP_FILE")" && pwd)"
BACKUP_NAME="$(basename "$BACKUP_FILE")"

echo "Restoring volumes from $BACKUP_DIR/$BACKUP_NAME ..."

# Use a read-only mount of the backup directory, resolve path safely,
# and fail fast if cleanup or extraction fails.
docker run --rm \
    -v ollama_storage:/ollama_storage \
    -v open_webui_data:/open_webui_data \
    -v "$BACKUP_DIR":/backup:ro \
    alpine sh -e -c '
        rm -rf /ollama_storage/* /open_webui_data/* /ollama_storage/.[!.]* /open_webui_data/.[!.]* /ollama_storage/..?* /open_webui_data/..?* 2>/dev/null || true
        tar xzf /backup/"$1" -C /
    ' sh "$BACKUP_NAME"

echo "Done. Restart with: task boot"
