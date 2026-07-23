#!/bin/bash

source "$(dirname "$0")/../.env" 2>/dev/null

echo "=== Ollama Server Status ==="
echo ""

if docker ps --format '{{.Names}}' | grep -q '^ollama_server$'; then
    echo "Container: RUNNING"
else
    echo "Container: STOPPED"
    exit 1
fi

echo ""
echo "API health check:"
timeout 2 bash -c "echo > /dev/tcp/localhost/${OLLAMA_HOST_PORT:-11434}" 2>/dev/null && echo "  HTTP 200" || echo "  UNREACHABLE"

echo ""
echo "Loaded models:"
docker exec ollama_server ollama ps 2>/dev/null || echo "  (none loaded)"
