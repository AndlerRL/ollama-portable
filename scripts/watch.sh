#!/bin/bash

source "$(dirname "$0")/../.env" 2>/dev/null

# ── ANSI escape codes ──────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
MAGENTA='\033[35m'
RESET='\033[0m'

# ── State ─────────────────────────────────────────────────────────
RECORDING=false
RECORD_PID=""
SESSION_FILE="$HOME/.ollama-portable/sessions/live.json"

# ── Cleanup on exit ───────────────────────────────────────────────
cleanup() {
	tput cnorm 2>/dev/null
	echo -e "\n${RESET}Exiting."
	exit 0
}
trap cleanup SIGINT SIGTERM

# ── Helpers ────────────────────────────────────────────────────────

# Build a 20-char CPU bar from a float percentage
cpu_bar() {
	local pct="${1%.*}"
	[[ -z "$pct" ]] && pct=0
	(( pct > 100 )) && pct=100
	local filled=$(( pct * 20 / 100 ))
	local empty=$(( 20 - filled ))
	local bar=""
	local i
	for (( i = 0; i < filled; i++ )); do bar+="█"; done
	for (( i = 0; i < empty; i++ )); do bar+="░"; done
	printf '%s' "$bar"
}

# Colour a value based on threshold: <50 green, 50-80 yellow, >80 red
colour_pct() {
	local val="${1%.*}"
	[[ -z "$val" ]] && val=0
	if (( val < 50 )); then
		printf "${GREEN}%s${RESET}" "$1"
	elif (( val <= 80 )); then
		printf "${YELLOW}%s${RESET}" "$1"
	else
		printf "${RED}%s${RESET}" "$1"
	fi
}

# Check if record.sh is running
check_recording() {
	RECORD_PID=$(pgrep -f 'record\.sh' 2>/dev/null | head -1)
	if [[ -n "$RECORD_PID" ]]; then
		RECORDING=true
	else
		RECORDING=false
	fi
}

# ── Data fetchers ──────────────────────────────────────────────────

fetch_container_stats() {
	docker stats ollama_server --no-stream \
		--format '{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.Name}}' 2>/dev/null
}

fetch_active_models() {
	docker exec ollama_server ollama ps 2>/dev/null | tail -n +2
}

fetch_recent_logs() {
	docker logs --tail 5 ollama_server 2>&1 | tail -5
}

# Parse live.json without jq
parse_live_json() {
	[[ -f "$SESSION_FILE" ]] || return 1

	local active
	active=$(grep -o '"active"[[:space:]]*:[[:space:]]*[a-z]*' "$SESSION_FILE" | head -1 | sed 's/.*: *//; s/"//g')
	[[ "$active" == "true" ]] || return 1

	local model elapsed cpu mem cpu_peak mem_peak snapshots
	model=$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$SESSION_FILE" | head -1 | sed 's/.*"model"[[:space:]]*:[[:space:]]*"//; s/"$//')
	elapsed=$(grep -o '"elapsed"[[:space:]]*:[[:space:]]*"[^"]*"' "$SESSION_FILE" | head -1 | sed 's/.*"elapsed"[[:space:]]*:[[:space:]]*"//; s/"$//')
	cpu=$(grep -o '"cpu"[[:space:]]*:[[:space:]]*[0-9.]*' "$SESSION_FILE" | head -1 | sed 's/.*: *//')
	cpu_peak=$(grep -o '"cpu_peak"[[:space:]]*:[[:space:]]*[0-9.]*' "$SESSION_FILE" | head -1 | sed 's/.*: *//')
	mem=$(grep -o '"mem"[[:space:]]*:[[:space:]]*"[^"]*"' "$SESSION_FILE" | head -1 | sed 's/.*"mem"[[:space:]]*:[[:space:]]*"//; s/"$//')
	mem_peak=$(grep -o '"mem_peak"[[:space:]]*:[[:space:]]*"[^"]*"' "$SESSION_FILE" | head -1 | sed 's/.*"mem_peak"[[:space:]]*:[[:space:]]*"//; s/"$//')
	snapshots=$(grep -o '"snapshots"[[:space:]]*:[[:space:]]*[0-9]*' "$SESSION_FILE" | head -1 | sed 's/.*: *//')

	printf '%s\n' "$model"
	printf '%s\n' "$elapsed"
	printf '%s\n' "$cpu"
	printf '%s\n' "$cpu_peak"
	printf '%s\n' "$mem"
	printf '%s\n' "$mem_peak"
	printf '%s\n' "$snapshots"
	return 0
}

# ── Render ─────────────────────────────────────────────────────────

render() {
	clear

	local now
	now=$(date '+%Y-%m-%d %H:%M:%S')

	# ── Header ─────────────────────────────────────────────────
	echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
	printf "  ${BOLD}OLLAMA MONITOR${RESET}  |  ${CYAN}ollama_server${RESET}  |  ${DIM}%s${RESET}\n" "$now"
	echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
	echo ""

	# ── Container stats ────────────────────────────────────────
	echo -e "${BOLD}── CONTAINER ─────────────────────────────────────────────${RESET}"

	local stats
	stats=$(fetch_container_stats)

	if [[ -z "$stats" ]]; then
		echo "  ${RED}Container not running.${RESET}"
	else
		local cpu_pct mem_usage net_io
		cpu_pct=$(echo "$stats" | cut -d',' -f1 | sed 's/%//')
		mem_usage=$(echo "$stats" | cut -d',' -f2)
		net_io=$(echo "$stats" | cut -d',' -f3)

		local cpu_bar_str
		cpu_bar_str=$(cpu_bar "$cpu_pct")
		local cpu_coloured
		cpu_coloured=$(colour_pct "${cpu_pct}%")

		printf "  CPU:  %s  %s" "$cpu_bar_str" "$cpu_coloured"

		# RAM
		local mem_used mem_total
		mem_used=$(echo "$mem_usage" | awk '{print $1}')
		mem_total=$(echo "$mem_usage" | awk '{print $3}')
		printf "    RAM: %s / %s\n" "$mem_used" "$mem_total"

		# NET + UPTIME
		local rx tx
		rx=$(echo "$net_io" | awk '{print $1 $2}')
		tx=$(echo "$net_io" | awk '{print $4 $5}')

		local uptime_str
		uptime_str=$(docker inspect ollama_server --format '{{.State.StartedAt}}' 2>/dev/null | xargs -I{} date -j -f '%Y-%m-%dT%H:%M:%S' "{}" '+%s' 2>/dev/null)
		if [[ -n "$uptime_str" ]]; then
			local now_epoch diff
			now_epoch=$(date '+%s')
			diff=$(( now_epoch - uptime_str ))
			local h m
			h=$(( diff / 3600 ))
			m=$(( (diff % 3600) / 60 ))
			uptime_str="${h}h ${m}m"
		else
			uptime_str="?"
		fi

		printf "  NET:  RX %s  TX %s     UPTIME: %s\n" "$rx" "$tx" "$uptime_str"
	fi

	echo ""

	# ── Active models ──────────────────────────────────────────
	echo -e "${BOLD}── ACTIVE MODELS ─────────────────────────────────────────${RESET}"

	local models
	models=$(fetch_active_models)

	if [[ -z "$models" ]]; then
		echo "  ${DIM}(none loaded)${RESET}"
	else
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			local name size gpu until
			name=$(echo "$line" | awk '{print $1}')
			size=$(echo "$line" | awk '{print $2 $3}')
			gpu=$(echo "$line" | awk '{print $4 $5}')
			until=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
			printf "  ${CYAN}%-16s${RESET}  SIZE: %-8s  GPU: %-6s  UNTIL: %s\n" "$name" "$size" "$gpu" "$until"
		done <<< "$models"
	fi

	echo ""

	# ── Live session ───────────────────────────────────────────
	echo -e "${BOLD}── LIVE SESSION ──────────────────────────────────────────${RESET}"

	local live_data
	live_data=$(parse_live_json 2>/dev/null)

	if [[ -z "$live_data" ]]; then
		echo "  ${DIM}No active session. Run 'task record' to start recording.${RESET}"
	else
		local l_model l_elapsed l_cpu l_cpu_peak l_mem l_mem_peak l_snapshots
		{
			IFS=$'\n' read -r l_model
			IFS=$'\n' read -r l_elapsed
			IFS=$'\n' read -r l_cpu
			IFS=$'\n' read -r l_cpu_peak
			IFS=$'\n' read -r l_mem
			IFS=$'\n' read -r l_mem_peak
			IFS=$'\n' read -r l_snapshots
		} <<< "$live_data"

		printf "  Model: ${CYAN}%s${RESET}    Elapsed: %s\n" "$l_model" "$l_elapsed"
		printf "  CPU:  %s (peak: %s%%)    MEM: %s (peak: %s)\n" \
			"$(colour_pct "${l_cpu}%")" "$l_cpu_peak" "$l_mem" "$l_mem_peak"
		printf "  Snapshots: %s\n" "$l_snapshots"
	fi

	echo ""

	# ── Recent logs ────────────────────────────────────────────
	echo -e "${BOLD}── RECENT LOGS ──────────────────────────────────────────${RESET}"

	local logs
	logs=$(fetch_recent_logs)

	if [[ -z "$logs" ]]; then
		echo "  ${DIM}(no logs)${RESET}"
	else
		while IFS= read -r log_line; do
			[[ -z "$log_line" ]] && continue
			printf "  ${DIM}%s${RESET}\n" "$log_line"
		done <<< "$logs"
	fi

	echo ""

	# ── Key bar ────────────────────────────────────────────────
	check_recording
	local rec_status
	if $RECORDING; then
		rec_status="${GREEN}ON${RESET}"
	else
		rec_status="${DIM}OFF${RESET}"
	fi

	echo -e "${DIM}Keys: Q=Quit  R=Record [${rec_status}${DIM}]  S=Session history${RESET}"
	echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
}

# ── Keyboard input (non-blocking) ──────────────────────────────────

read_key() {
	# Read a single key with a 0.1s timeout
	read -rsn1 -t 0.1 key 2>/dev/null
	if [[ -z "$key" ]]; then
		return 1
	fi
	# Handle escape sequences (arrow keys etc.)
	if [[ "$key" == $'\e' ]]; then
		read -rsn2 -t 0.01 esc_rest 2>/dev/null
		key+="$esc_rest"
	fi
	return 0
}

handle_key() {
	case "$key" in
		q|Q)
			cleanup
			;;
		r|R)
			toggle_recording
			;;
		s|S)
			# Show hint then wait for any key
			clear
			echo ""
			echo "  Session history is available via:"
			echo ""
			echo "    task sessions"
			echo ""
			echo "  This lists all recorded sessions in ~/.ollama-portable/sessions/"
			echo ""
			echo -n "  Press any key to return..."
			read -rsn1
			;;
	esac
}

toggle_recording() {
	if $RECORDING; then
		if [[ -n "$RECORD_PID" ]]; then
			kill "$RECORD_PID" 2>/dev/null
		fi
		RECORDING=false
	else
		local script_dir
		script_dir="$(dirname "$0")"
		if [[ -f "$script_dir/record.sh" ]]; then
			bash "$script_dir/record.sh" &
			RECORDING=true
		fi
	fi
}

# ── Main loop ──────────────────────────────────────────────────────

tput civis 2>/dev/null  # hide cursor

while true; do
	render

	# Non-blocking key read loop for ~2 seconds
	local start_time
	start_time=$(date +%s%N 2>/dev/null || date +%s)
	local elapsed=0

	while true; do
		if read_key; then
			handle_key
		fi

		# Check elapsed time
		local now_time
		now_time=$(date +%s%N 2>/dev/null || date +%s)
		if [[ "$start_time" == *N* ]]; then
			elapsed=$(( (now_time - start_time) / 1000000000 ))
		else
			elapsed=$(( now_time - start_time ))
		fi

		(( elapsed >= 2 )) && break
	done
done
