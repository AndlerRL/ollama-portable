#!/bin/bash
#
# sessions.sh — Ollama session history viewer
# Reads all recorded inference sessions from ~/.ollama-portable/sessions/
# and displays a summary table with peak analysis and model aggregates.
#
# Usage:
#   ./sessions.sh                  Show summary of all sessions
#   ./sessions.sh <session_id>     Show detailed view of a specific session
#

set -euo pipefail

SESSIONS_DIR="$HOME/.ollama-portable/sessions"

# ── formatting helpers ───────────────────────────────────────────────────────

fmt_duration() {
	local secs=${1%.*}
	if (( secs >= 3600 )); then
		printf '%dh %dm %ds' $((secs / 3600)) $(((secs % 3600) / 60)) $((secs % 60))
	elif (( secs >= 60 )); then
		printf '%dm %ds' $((secs / 60)) $((secs % 60))
	else
		printf '%ds' "$secs"
	fi
}

fmt_memory() {
	local mb=${1%.*}
	if (( mb >= 1000 )); then
		awk -v mb="$1" 'BEGIN { printf "%.1fGB", mb / 1024 }'
	else
		printf '%dMB' "$mb"
	fi
}

fmt_cpu() {
	printf '%.1f%%' "$1"
}

# ── JSON parsing (no jq — grep/sed/awk only) ────────────────────────────────

# Extract a string value for a given top-level key
json_str() {
	local key="$1" file="$2"
	grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
		| head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true
}

# Extract a numeric value for a given top-level key
json_num() {
	local key="$1" file="$2"
	grep -o "\"$key\"[[:space:]]*:[[:space:]]*[0-9.]*" "$file" 2>/dev/null \
		| head -1 | sed 's/.*:[[:space:]]*//' || true
}

# Parse all snapshots and compute aggregate stats
# Output (space-separated): peak_cpu peak_mem avg_cpu avg_mem snapshot_count
snapshot_stats() {
	local file="$1" cpu_vals mem_vals count peak_cpu peak_mem sum_cpu sum_mem

	cpu_vals=$(grep -o '"cpu"[[:space:]]*:[[:space:]]*[0-9.]*' "$file" 2>/dev/null \
		| sed 's/.*:[[:space:]]*//' || true)
	mem_vals=$(grep -o '"memory_mb"[[:space:]]*:[[:space:]]*[0-9.]*' "$file" 2>/dev/null \
		| sed 's/.*:[[:space:]]*//' || true)

	count=$(printf '%s\n' "$cpu_vals" | wc -l | tr -d ' ')
	if [ "$count" -eq 0 ] || [ -z "$cpu_vals" ]; then
		echo "0 0 0 0 0"
		return
	fi

	peak_cpu=$(printf '%s' "$cpu_vals" | sort -rn | head -1)
	peak_mem=$(printf '%s' "$mem_vals" | sort -rn | head -1)
	sum_cpu=$(printf '%s' "$cpu_vals" | awk '{s+=$1} END {print s+0}')
	sum_mem=$(printf '%s' "$mem_vals" | awk '{s+=$1} END {print s+0}')
	avg_cpu=$(awk -v s="$sum_cpu" -v c="$count" 'BEGIN { printf "%.1f", s/c }')
	avg_mem=$(awk -v s="$sum_mem" -v c="$count" 'BEGIN { printf "%.1f", s/c }')

	echo "$peak_cpu $peak_mem $avg_cpu $avg_mem $count"
}

# Extract timestamp+cpu pairs from the snapshots array
# Output: one line per snapshot — timestamp<TAB>cpu
snapshot_timeline() {
	local file="$1"
	awk '
	BEGIN { in_snap=0; ts=""; cpu="" }
	/"snapshots"/          { in_snap=1; next }
	in_snap && /\]/ && !/\{/ { in_snap=0; next }
	in_snap && /"timestamp"/ {
		ts=$0
		sub(/.*"timestamp"[[:space:]]*:[[:space:]]*"/, "", ts)
		sub(/".*/, "", ts)
		if (cpu != "") { print ts "\t" cpu; ts=""; cpu="" }
	}
	in_snap && /"cpu"/ {
		cpu=$0
		sub(/.*"cpu"[[:space:]]*:[[:space:]]*/, "", cpu)
		sub(/[,}].*/, "", cpu)
		gsub(/^[[:space:]]+|[[:space:]]+$/, "", cpu)
		if (ts != "") { print ts "\t" cpu; ts=""; cpu="" }
	}
	' "$file"
}

# Build a bar chart string — each █ represents 10% CPU
bar_chart() {
	local cpu="$1" n bars
	n=$(awk -v c="$cpu" 'BEGIN { printf "%d", c/10 }')
	bars=""
	for ((i=0; i<n; i++)); do bars+="█"; done
	printf '%s' "$bars"
}

# ── detail view ──────────────────────────────────────────────────────────────

show_detail() {
	local session_id="$1" file

	if [ -f "$SESSIONS_DIR/${session_id}.json" ]; then
		file="$SESSIONS_DIR/${session_id}.json"
	elif [ -f "$SESSIONS_DIR/${session_id}" ]; then
		file="$SESSIONS_DIR/${session_id}"
	else
		echo "Session not found: $session_id"
		exit 1
	fi

	local model started ended duration snap_count
	model=$(json_str "model" "$file")
	started=$(json_str "started" "$file")
	ended=$(json_str "ended" "$file")
	duration=$(json_num "duration_seconds" "$file")

	read -r peak_cpu peak_mem avg_cpu avg_mem snap_count <<< "$(snapshot_stats "$file")"

	local min_cpu min_mem
	min_cpu=$(grep -o '"cpu"[[:space:]]*:[[:space:]]*[0-9.]*' "$file" 2>/dev/null \
		| sed 's/.*:[[:space:]]*//' | sort -n | head -1 || echo "0")
	min_mem=$(grep -o '"memory_mb"[[:space:]]*:[[:space:]]*[0-9.]*' "$file" 2>/dev/null \
		| sed 's/.*:[[:space:]]*//' | sort -n | head -1 || echo "0")

	local started_fmt ended_fmt
	started_fmt=$(echo "$started" | sed 's/T/ /')
	ended_fmt=$(echo "$ended" | sed 's/T/ /')

	echo "═══════════════════════════════════════════════════════════════════════════════"
	printf '  SESSION: %s\n' "$session_id"
	echo "═══════════════════════════════════════════════════════════════════════════════"
	echo ""
	printf '  Model:      %s\n' "$model"
	printf '  Started:    %s\n' "$started_fmt"
	printf '  Ended:      %s\n' "$ended_fmt"
	printf '  Duration:   %s\n' "$(fmt_duration "$duration")"
	printf '  Snapshots:  %s\n' "$snap_count"
	echo ""
	printf '  CPU:  Avg %s  |  Peak %s  |  Min %s\n' \
		"$(fmt_cpu "$avg_cpu")" "$(fmt_cpu "$peak_cpu")" "$(fmt_cpu "$min_cpu")"
	printf '  MEM:  Avg %s  |  Peak %s   |  Min %s\n' \
		"$(fmt_memory "$avg_mem")" "$(fmt_memory "$peak_mem")" "$(fmt_memory "$min_mem")"
	echo ""
	echo "── CPU TIMELINE (each █ = 10%) ──────────────────────────────────────────────"

	local timeline count total_lines
	timeline=$(snapshot_timeline "$file")
	total_lines=$(printf '%s' "$timeline" | wc -l | tr -d ' ')
	count=0

	while IFS=$'\t' read -r ts cpu_val; do
		[ -z "$ts" ] && continue
		count=$((count + 1))
		if [ "$count" -le 20 ]; then
			local time_part bars marker
			time_part=$(echo "$ts" | grep -o '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]' || echo "$ts")
			bars=$(bar_chart "$cpu_val")
			marker=""
			if [ "$(awk -v a="$cpu_val" -v b="$peak_cpu" 'BEGIN { print (a+0 >= b+0) ? "1" : "0" }')" = "1" ]; then
				marker="  ⚡ PEAK"
			fi
			printf '  %s  %-25s %s%s\n' "$time_part" "$bars" "$(fmt_cpu "$cpu_val")" "$marker"
		fi
	done <<< "$timeline" || true

	local remaining=$((total_lines - 20))
	if [ "$remaining" -gt 0 ]; then
		echo "  ... $remaining more snapshots ..."
	fi
}

# ── summary view ─────────────────────────────────────────────────────────────

show_summary() {
	if [ ! -d "$SESSIONS_DIR" ]; then
		echo "No sessions recorded yet. Run 'task record' to start recording."
		exit 0
	fi

	local files=()
	local f
	for f in "$SESSIONS_DIR"/*.json; do
		[ -f "$f" ] || continue
		[ "$(basename "$f")" = "live.json" ] && continue
		files+=("$f")
	done

	if [ ${#files[@]} -eq 0 ]; then
		echo "No sessions recorded yet. Run 'task record' to start recording."
		exit 0
	fi

	TMPFILE=$(mktemp) || exit 1
	trap 'rm -f "$TMPFILE"' EXIT

	local total_sessions=0 total_duration=0
	local peak_cpu_session="" peak_cpu_val=0
	local peak_mem_session="" peak_mem_val=0
	local longest_session="" longest_duration=0

	for f in "${files[@]}"; do
		local sid model started duration
		sid=$(basename "$f" .json)
		model=$(json_str "model" "$f")
		started=$(json_str "started" "$f")
		duration=$(json_num "duration_seconds" "$f")

		# Skip corrupt files that lack required fields
		if [ -z "$model" ] || [ -z "$started" ]; then
			echo "Warning: skipping corrupt session file: $sid" >&2
			continue
		fi

		read -r p_cpu p_mem a_cpu a_mem s_count <<< "$(snapshot_stats "$f")"

		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$sid" "$model" "$started" "$duration" "$p_cpu" "$p_mem" "$a_cpu" "$a_mem" "$s_count" \
			>> "$TMPFILE"

		total_sessions=$((total_sessions + 1))
		total_duration=$((total_duration + ${duration%.*}))

		# Track global peaks across all sessions
		if [ "$(awk -v a="$p_cpu" -v b="$peak_cpu_val" 'BEGIN { print (a+0 > b+0) ? "1" : "0" }')" = "1" ]; then
			peak_cpu_val=$p_cpu
			peak_cpu_session=$sid
		fi
		if [ "$(awk -v a="$p_mem" -v b="$peak_mem_val" 'BEGIN { print (a+0 > b+0) ? "1" : "0" }')" = "1" ]; then
			peak_mem_val=$p_mem
			peak_mem_session=$sid
		fi
		if [ "$(awk -v a="$duration" -v b="$longest_duration" 'BEGIN { print (a+0 > b+0) ? "1" : "0" }')" = "1" ]; then
			longest_duration=${duration%.*}
			longest_session=$sid
		fi
	done

	# ── header ────────────────────────────────────────────────────────────
	echo "═══════════════════════════════════════════════════════════════════════════════"
	printf '  OLLAMA SESSION HISTORY  |  %d sessions recorded\n' "$total_sessions"
	echo "═══════════════════════════════════════════════════════════════════════════════"
	echo ""
	printf '  %-12s %-10s %-8s %-20s %-10s %-10s %-10s\n' \
		"ID" "DATE" "TIME" "MODEL" "DURATION" "PEAK CPU" "PEAK MEM"
	echo "  ─────────────────────────────────────────────────────────────────────────────"

	# ── table rows ─────────────────────────────────────────────────────────
	local index=0
	while IFS=$'\t' read -r sid model started duration p_cpu p_mem a_cpu a_mem s_count; do
		index=$((index + 1))
		local idx_fmt date_part time_part dur_fmt cpu_fmt mem_fmt marker
		idx_fmt=$(printf '%03d' "$index")
		date_part=$(echo "$started" | cut -d'T' -f1)
		time_part=$(echo "$started" | cut -d'T' -f2 | cut -d'.' -f1)
		dur_fmt=$(fmt_duration "$duration")
		cpu_fmt=$(fmt_cpu "$p_cpu")
		mem_fmt=$(fmt_memory "$p_mem")
		marker=""
		[ "$sid" = "$peak_cpu_session" ] && marker="  ⚡"

		printf '  %-12s %-10s %-8s %-20s %-10s %-10s %-10s%s\n' \
			"$idx_fmt" "$date_part" "$time_part" "$model" "$dur_fmt" "$cpu_fmt" "$mem_fmt" "$marker"
	done < "$TMPFILE" || true

	# ── peak analysis ──────────────────────────────────────────────────────
	echo ""
	echo "  ── PEAK ANALYSIS ────────────────────────────────────────────────────────────"

	local peak_cpu_model peak_mem_model longest_model
	peak_cpu_model=$(json_str "model" "$SESSIONS_DIR/${peak_cpu_session}.json")
	peak_mem_model=$(json_str "model" "$SESSIONS_DIR/${peak_mem_session}.json")
	longest_model=$(json_str "model" "$SESSIONS_DIR/${longest_session}.json")

	local peak_cpu_started peak_mem_started longest_started
	peak_cpu_started=$(json_str "started" "$SESSIONS_DIR/${peak_cpu_session}.json" | sed 's/T/ /')
	peak_mem_started=$(json_str "started" "$SESSIONS_DIR/${peak_mem_session}.json" | sed 's/T/ /')
	longest_started=$(json_str "started" "$SESSIONS_DIR/${longest_session}.json" | sed 's/T/ /')

	local peak_cpu_idx peak_mem_idx longest_idx
	peak_cpu_idx=$(grep -n -F "$peak_cpu_session" "$TMPFILE" | cut -d: -f1 || echo "?")
	peak_mem_idx=$(grep -n -F "$peak_mem_session" "$TMPFILE" | cut -d: -f1 || echo "?")
	longest_idx=$(grep -n -F "$longest_session" "$TMPFILE" | cut -d: -f1 || echo "?")

	printf '    Highest CPU:     Session %s — %s at %s (%s)\n' \
		"$(printf '%03d' "$peak_cpu_idx")" "$peak_cpu_model" "$(fmt_cpu "$peak_cpu_val")" "$peak_cpu_started"
	printf '    Highest Memory:  Session %s — %s at %s (%s)\n' \
		"$(printf '%03d' "$peak_mem_idx")" "$peak_mem_model" "$(fmt_memory "$peak_mem_val")" "$peak_mem_started"
	printf '    Longest:         Session %s — %s at %s\n' \
		"$(printf '%03d' "$longest_idx")" "$longest_model" "$(fmt_duration "$longest_duration")"
	printf '    Total recorded:  %s across %d sessions\n' "$(fmt_duration "$total_duration")" "$total_sessions"

	# ── model aggregates ──────────────────────────────────────────────────
	echo ""
	echo "  ── MODEL AGGREGATES ─────────────────────────────────────────────────────────"
	printf '    %-20s %-10s %-10s %-10s %-15s\n' \
		"MODEL" "SESSIONS" "AVG CPU" "PEAK CPU" "AVG DURATION"

	awk -F'\t' '
	{
		model=$2
		count[model]++
		sum_avg_cpu[model] += $7
		if ($5+0 > peak_cpu[model]+0) peak_cpu[model] = $5
		sum_duration[model] += $4
	}
	END {
		for (m in count) {
			avg_cpu = sum_avg_cpu[m] / count[m]
			avg_dur = sum_duration[m] / count[m]
			printf "%s\t%d\t%.1f\t%.1f\t%d\n", m, count[m], avg_cpu, peak_cpu[m], avg_dur
		}
	}
	' "$TMPFILE" | sort -t$'\t' -k2,2rn | while IFS=$'\t' read -r model sessions avg_cpu peak_cpu avg_dur; do
		printf '    %-20s %-10s %-10s %-10s %-15s\n' \
			"$model" "$sessions" "$(fmt_cpu "$avg_cpu")" "$(fmt_cpu "$peak_cpu")" "$(fmt_duration "$avg_dur")"
	done || true

	echo ""
	echo "  Usage: sessions.sh [session_id]  — show details for a specific session"
}

# ── main ─────────────────────────────────────────────────────────────────────

if [ $# -gt 0 ]; then
	show_detail "$1"
else
	show_summary
fi
