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

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

docker run --rm -v ollama_storage:/data:ro -v "$TMPDIR":/out alpine cp -a /data/. /out/ollama_storage/
docker run --rm -v open_webui_data:/data:ro -v "$TMPDIR":/out alpine cp -a /data/. /out/open_webui_data/

tar czf "$PROJECT_ROOT/$BACKUP_FILE" -C "$TMPDIR" .
echo "Done: $PROJECT_ROOT/$BACKUP_FILE"
