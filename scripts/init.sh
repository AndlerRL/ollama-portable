#!/bin/bash

SELECTED_MODEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model|-m) SELECTED_MODEL="$2"; shift 2 ;;
        --model=*|-m=*) SELECTED_MODEL="${1#*=}"; shift ;;
        *) shift ;;
    esac
done

if [ -z "$SELECTED_MODEL" ]; then
    clear
    echo "======================================================"
    echo "          OLLAMA MODEL BOOT SELECTOR"
    echo "======================================================"
    echo "Available optimized Cloud/Local Models:"
    echo " 1) qwen2.5:1.5b    (Default - Balanced Speed/Intellect)"
    echo " 2) llama3.2:1b     (Ultra-Lightweight)"
    echo " 3) deepseek-r1:1.5b (Advanced Reasoning/Math)"
    echo " 4) qwen2.5:0.5b    (Fastest execution for old CPUs)"
    echo " 5) Custom           (Type any model ID manually)"
    echo "======================================================"

    echo "Enter model name, option number, or press Enter for default..."
    read -t 5 -p "Model Choice [Timeout 5s]: " USER_INPUT

    if [ -z "$USER_INPUT" ]; then
        USER_INPUT="1"
    fi

    case "$USER_INPUT" in
        1) SELECTED_MODEL="qwen2.5:1.5b" ;;
        2) SELECTED_MODEL="llama3.2:1b" ;;
        3) SELECTED_MODEL="deepseek-r1:1.5b" ;;
        4) SELECTED_MODEL="qwen2.5:0.5b" ;;
        5)
            read -p "Enter custom model ID: " SELECTED_MODEL
            if [ -z "$SELECTED_MODEL" ]; then
                echo "No model specified. Exiting."
                exit 1
            fi
            ;;
        *) SELECTED_MODEL="$USER_INPUT" ;;
    esac
fi

echo -e "\nExecuting environment with model: **$SELECTED_MODEL**\n"

# Detect hardware and get the right compose files
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/detect.sh"

cd "$PROJECT_ROOT"

# Step 1: Start ollama_server (no puller service)
echo "Starting ollama_server..."
docker compose $COMPOSE_FILES up -d ollama_server

# Step 2: Wait for server to be ready
echo "Waiting for ollama_server to be ready..."
for i in $(seq 1 60); do
    if docker exec ollama_server ollama list >/dev/null 2>&1; then
        echo "Server ready."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "ERROR: ollama_server did not become ready after 180s"
        exit 1
    fi
    sleep 3
done

# Step 3: Pull the model
echo "Pulling model: $SELECTED_MODEL ..."
docker exec ollama_server ollama pull "$SELECTED_MODEL"

echo ""
echo "Boot complete. Server running on http://localhost:${OLLAMA_HOST_PORT:-11434}"
