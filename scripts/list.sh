#!/bin/bash
# Auto-detect TTY: use -it only when running interactively
if [ -t 1 ]; then
    docker exec -it ollama_server ollama list
else
    docker exec ollama_server ollama list
fi
