#!/bin/bash

LINES=50
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
		*)
			shift
			;;
	esac
done
docker logs --tail "$LINES" -f ollama_server
