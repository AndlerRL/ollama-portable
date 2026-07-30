#!/bin/bash

LINES=50
FOLLOW="-f"

# Ensure logs directory exists
LOG_DIR="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/logs"
mkdir -p "$LOG_DIR"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lines|-n)
            if [[ -z "${2:-}" ]]; then
                echo "Error: $1 requires a value" >&2
                exit 1
            fi
            LINES="$2"
            shift 2
            ;;
        --lines=*)
            LINES="${1#*=}"
            shift
            ;;
        -n*)
            LINES="${1#-n}"
            shift
            ;;
        --follow|-f)
            FOLLOW="-f"
            shift
            ;;
        --no-follow)
            FOLLOW=""
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo "[logs] docker logs --tail $LINES ${FOLLOW:+$FOLLOW }ollama_server" | tee -a "$LOG_DIR/audit.log"

docker logs --tail "$LINES" $FOLLOW ollama_server
