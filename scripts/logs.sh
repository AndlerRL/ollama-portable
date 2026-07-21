#!/bin/bash

LINES=50
FOLLOW=""

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
        *)
            shift
            ;;
    esac
done

docker logs --tail "$LINES" $FOLLOW ollama_server
