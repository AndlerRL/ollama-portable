#!/bin/bash

MODEL_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model|-m) MODEL_ID="$2"; shift 2 ;;
        --model=*|-m=*) MODEL_ID="${1#*=}"; shift ;;
        *) shift ;;
    esac
done

if [ -z "$MODEL_ID" ]; then
    read -p "Model ID to inspect: " MODEL_ID
    if [ -z "$MODEL_ID" ]; then
        echo "No model specified. Exiting."
        exit 1
    fi
fi

docker exec -it ollama_server ollama show "$MODEL_ID"
