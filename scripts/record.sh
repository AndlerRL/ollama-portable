#!/bin/bash
set -euo pipefail

DATA_DIR="$HOME/.ollama-portable/sessions"
PID_FILE="$HOME/.ollama-portable/record.pid"
LIVE_FILE="$DATA_DIR/live.json"
POLL_INTERVAL=2

# --- Stop command ---
if [ "${1:-}" = "stop" ]; then
	if [ -f "$PID_FILE" ]; then
		PID=$(cat "$PID_FILE")
		if kill -0 "$PID" 2>/dev/null; then
			kill "$PID"
			echo "Sent stop signal to record daemon (PID $PID)"
		else
			echo "PID file exists but process $PID is not running. Cleaning up."
			rm -f "$PID_FILE"
		fi
	else
		echo "No record daemon is running (no PID file found)."
	fi
	exit 0
fi

# --- Prevent duplicate instances ---
if [ -f "$PID_FILE" ]; then
	PID=$(cat "$PID_FILE")
	if kill -0 "$PID" 2>/dev/null; then
		echo "Record daemon is already running (PID $PID). Use '$0 stop' to stop it first."
		exit 1
	fi
	rm -f "$PID_FILE"
fi

# --- Ensure data directory exists ---
mkdir -p "$DATA_DIR"

# --- Write our own PID ---
echo $$ > "$PID_FILE"

# --- State variables ---
CURRENT_MODEL=""
SESSION_ID=""
START_TS=""
START_EPOCH=""
SNAPSHOTS=()
PEAK_CPU=0
PEAK_MEM_MB=0
SUM_CPU=0
SNAPSHOT_COUNT=0

# --- Cleanup on exit ---
cleanup() {
	trap - SIGINT SIGTERM EXIT

	# Close any active session
	if [ -n "$CURRENT_MODEL" ] && [ -n "$SESSION_ID" ]; then
		END_EPOCH=$(date +%s)
		END_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
		DURATION=$((END_EPOCH - START_EPOCH))

		# Compute averages
		if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
			AVG_CPU=$(awk "BEGIN {printf \"%.1f\", $SUM_CPU / $SNAPSHOT_COUNT}")
		else
			AVG_CPU=0
		fi

		# Write session JSON
		SESSION_FILE="$DATA_DIR/${SESSION_ID}.json"
		{
			echo '{'
			echo "  \"session_id\": \"$SESSION_ID\","
			echo "  \"model\": \"$CURRENT_MODEL\","
			echo "  \"start\": \"$START_TS\","
			echo "  \"end\": \"$END_TS\","
			echo "  \"duration_seconds\": $DURATION,"
			echo "  \"peak_cpu_percent\": $PEAK_CPU,"
			echo "  \"peak_memory_mb\": $PEAK_MEM_MB,"
			echo "  \"avg_cpu_percent\": $AVG_CPU,"
			echo '  "snapshots": ['
			for i in "${!SNAPSHOTS[@]}"; do
				COMMA=","
				if [ "$i" -eq $((${#SNAPSHOTS[@]} - 1)) ]; then
					COMMA=""
				fi
				echo "    ${SNAPSHOTS[$i]}$COMMA"
			done
			echo '  ]'
			echo '}'
		} > "$SESSION_FILE"

		echo "Session ended: $CURRENT_MODEL (${DURATION}s, peak CPU: ${PEAK_CPU}%)"
	fi

	# Write inactive live status
	echo '{"active": false}' > "$LIVE_FILE"

	rm -f "$PID_FILE"
	exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# --- Parse docker stats line ---
# Input: "12.34%,1234MiB / 8192MiB"
# Output: sets CPU_VAL and MEM_MB
parse_stats() {
	local line="$1"
	CPU_RAW=$(echo "$line" | awk -F',' '{print $1}' | tr -d '%')
	MEM_RAW=$(echo "$line" | awk -F',' '{print $2}' | awk '{print $1}')
	CPU_VAL=$(awk "BEGIN {printf \"%.1f\", $CPU_RAW}")
	MEM_MB=$(echo "$MEM_RAW" | sed 's/MiB//' | sed 's/GiB//')
	# Handle GiB → MiB conversion
	if echo "$MEM_RAW" | grep -q 'GiB'; then
		MEM_MB=$(awk "BEGIN {printf \"%.1f\", $MEM_MB * 1024}")
	else
		MEM_MB=$(awk "BEGIN {printf \"%.1f\", $MEM_MB}")
	fi
}

# --- Parse ollama ps to get loaded model name ---
# Input: multiline output from `ollama ps`
# Output: model name or empty string
parse_model() {
	local ps_output="$1"
	# ollama ps output format:
	# NAME            ID              SIZE      PROCESSOR    UNTIL
	# qwen2.5:1.5b    abc123...       1.5 GB    100% GPU     4 minutes from now
	# Skip the header line, extract the first column
	echo "$ps_output" | tail -n +2 | awk '{print $1}' | head -1
}

# --- Build a snapshot JSON object ---
build_snapshot() {
	local ts="$1"
	local cpu="$2"
	local mem_mb="$3"
	echo "{\"ts\": \"$ts\", \"cpu\": $cpu, \"mem_mb\": $mem_mb}"
}

# --- Update live.json ---
update_live() {
	local active="$1"
	if [ "$active" = "false" ]; then
		echo '{"active": false}' > "$LIVE_FILE"
		return
	fi

	local model="$2"
	local started="$3"
	local elapsed="$4"
	local cur_cpu="$5"
	local cur_mem="$6"
	local peak_cpu="$7"
	local peak_mem="$8"
	local count="$9"

	{
		echo '{'
		echo "  \"active\": true,"
		echo "  \"model\": \"$model\","
		echo "  \"started\": \"$started\","
		echo "  \"elapsed_seconds\": $elapsed,"
		echo "  \"current_cpu\": $cur_cpu,"
		echo "  \"current_mem_mb\": $cur_mem,"
		echo "  \"peak_cpu\": $peak_cpu,"
		echo "  \"peak_mem_mb\": $peak_mem,"
		echo "  \"snapshot_count\": $count"
		echo '}'
	} > "$LIVE_FILE"
}

# --- Close current session and write JSON ---
close_session() {
	if [ -z "$CURRENT_MODEL" ] || [ -z "$SESSION_ID" ]; then
		return
	fi

	END_EPOCH=$(date +%s)
	END_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	DURATION=$((END_EPOCH - START_EPOCH))

	if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
		AVG_CPU=$(awk "BEGIN {printf \"%.1f\", $SUM_CPU / $SNAPSHOT_COUNT}")
	else
		AVG_CPU=0
	fi

	SESSION_FILE="$DATA_DIR/${SESSION_ID}.json"
	{
		echo '{'
		echo "  \"session_id\": \"$SESSION_ID\","
		echo "  \"model\": \"$CURRENT_MODEL\","
		echo "  \"start\": \"$START_TS\","
		echo "  \"end\": \"$END_TS\","
		echo "  \"duration_seconds\": $DURATION,"
		echo "  \"peak_cpu_percent\": $PEAK_CPU,"
		echo "  \"peak_memory_mb\": $PEAK_MEM_MB,"
		echo "  \"avg_cpu_percent\": $AVG_CPU,"
		echo '  "snapshots": ['
		for i in "${!SNAPSHOTS[@]}"; do
			COMMA=","
			if [ "$i" -eq $((${#SNAPSHOTS[@]} - 1)) ]; then
				COMMA=""
			fi
			echo "    ${SNAPSHOTS[$i]}$COMMA"
		done
		echo '  ]'
		echo '}'
	} > "$SESSION_FILE"

	echo "Session ended: $CURRENT_MODEL (${DURATION}s, peak CPU: ${PEAK_CPU}%)"

	CURRENT_MODEL=""
	SESSION_ID=""
	START_TS=""
	START_EPOCH=""
	SNAPSHOTS=()
	PEAK_CPU=0
	PEAK_MEM_MB=0
	SUM_CPU=0
	SNAPSHOT_COUNT=0
}

# --- Start a new session ---
start_session() {
	local model="$1"
	CURRENT_MODEL="$model"
	START_EPOCH=$(date +%s)
	START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	# Build session_id: YYYYMMDD_HHMMSS_modelname
	local date_part
	date_part=$(date -u +"%Y%m%d_%H%M%S")
	local safe_model
	safe_model=$(echo "$model" | tr ':' '-')
	SESSION_ID="${date_part}_${safe_model}"

	SNAPSHOTS=()
	PEAK_CPU=0
	PEAK_MEM_MB=0
	SUM_CPU=0
	SNAPSHOT_COUNT=0

	echo "Session started: $model"
}

# --- Main polling loop ---
echo "Record daemon started (PID $$). Polling every ${POLL_INTERVAL}s."
echo "Data directory: $DATA_DIR"
echo "Use '$0 stop' to stop."

update_live "false"

while true; do
	# Check if container is running
	if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^ollama_server$'; then
		# Container not running — close any active session
		if [ -n "$CURRENT_MODEL" ]; then
			close_session
			update_live "false"
		fi
		sleep "$POLL_INTERVAL"
		continue
	fi

	# Capture docker stats
	STATS_LINE=$(docker stats ollama_server --no-stream --format '{{.CPUPerc}},{{.MemUsage}}' 2>/dev/null || true)

	# Capture loaded models
	PS_OUTPUT=$(docker exec ollama_server ollama ps 2>/dev/null || true)

	# Parse model name
	LOADED_MODEL=$(parse_model "$PS_OUTPUT")

	# Handle session transitions
	if [ -z "$LOADED_MODEL" ]; then
		# No model loaded — close session if one is active
		if [ -n "$CURRENT_MODEL" ]; then
			close_session
			update_live "false"
		fi
	else
		if [ -z "$CURRENT_MODEL" ]; then
			# Model appeared — start new session
			start_session "$LOADED_MODEL"
		elif [ "$LOADED_MODEL" != "$CURRENT_MODEL" ]; then
			# Model changed — close old, start new
			close_session
			start_session "$LOADED_MODEL"
		fi

		# Record snapshot if we have stats and an active session
		if [ -n "$STATS_LINE" ] && [ -n "$CURRENT_MODEL" ]; then
			parse_stats "$STATS_LINE"
			SNAP_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
			SNAPSHOT=$(build_snapshot "$SNAP_TS" "$CPU_VAL" "$MEM_MB")
			SNAPSHOTS+=("$SNAPSHOT")
			SNAPSHOT_COUNT=$((SNAPSHOT_COUNT + 1))

			# Update peaks
			PEAK_CPU=$(awk "BEGIN {if ($CPU_VAL > $PEAK_CPU) print $CPU_VAL; else print $PEAK_CPU}")
			PEAK_MEM_MB=$(awk "BEGIN {if ($MEM_MB > $PEAK_MEM_MB) print $MEM_MB; else print $PEAK_MEM_MB}")

			# Accumulate sum for average
			SUM_CPU=$(awk "BEGIN {printf \"%.1f\", $SUM_CPU + $CPU_VAL}")

			# Update live status
			NOW_EPOCH=$(date +%s)
			ELAPSED=$((NOW_EPOCH - START_EPOCH))
			update_live "true" "$CURRENT_MODEL" "$START_TS" "$ELAPSED" "$CPU_VAL" "$MEM_MB" "$PEAK_CPU" "$PEAK_MEM_MB" "$SNAPSHOT_COUNT"
		fi
	fi

	sleep "$POLL_INTERVAL"
done
