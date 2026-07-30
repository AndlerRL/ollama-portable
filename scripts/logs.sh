#!/bin/bash

LINES=50
FOLLOW="-f"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lines|-n)
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

docker logs --tail "$LINES" $FOLLOW ollama_server
