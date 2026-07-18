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
    clear
    echo "======================================================"
    echo "          OLLAMA MODEL PULLER"
    echo "======================================================"
    echo "Enter any Ollama model ID to pull into the container."
    echo "Examples: llama3.2, mistral, codellama:7b, nomic-embed-text"
    echo "======================================================"

    read -p "Model ID: " MODEL_ID

    if [ -z "$MODEL_ID" ]; then
        echo "No model specified. Exiting."
        exit 1
    fi
fi

echo -e "\nPulling model: $MODEL_ID ..."
docker exec -it ollama_server ollama pull "$MODEL_ID"
