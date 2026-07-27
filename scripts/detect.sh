#!/bin/bash

# detect.sh — Detect host GPU hardware and output Docker Compose configuration flags.
#
# Usage:
#   source scripts/detect.sh          # Source into another script (sets variables)
#   eval "$(bash scripts/detect.sh)"  # Eval the output
#   bash scripts/detect.sh --print    # Human-readable output

# ---------------------------------------------------------------------------
# System info helpers
# ---------------------------------------------------------------------------

detect_cpu_model() {
    if command -v sysctl &>/dev/null; then
        sysctl -n machdep.cpu.brand_string 2>/dev/null || true
    elif command -v lscpu &>/dev/null; then
        lscpu 2>/dev/null | grep "Model name" | cut -d: -f2 | xargs || true
    else
        uname -m
    fi
}

detect_cpu_cores() {
    if command -v sysctl &>/dev/null; then
        sysctl -n hw.ncpu 2>/dev/null || true
    elif command -v nproc &>/dev/null; then
        nproc 2>/dev/null || true
    else
        echo "unknown"
    fi
}

detect_ram_total() {
    if command -v sysctl &>/dev/null; then
        local bytes
        bytes=$(sysctl -n hw.memsize 2>/dev/null) || true
        if [ -n "$bytes" ] && [ "$bytes" -gt 0 ] 2>/dev/null; then
            echo "$((bytes / 1024 / 1024 / 1024)) GB"
        else
            echo "unknown"
        fi
    elif command -v free &>/dev/null; then
        local gb
        gb=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}') || true
        if [ -n "$gb" ]; then
            echo "${gb} GB"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# ---------------------------------------------------------------------------
# Container detection
# ---------------------------------------------------------------------------

is_inside_container() {
    if [ -f /.dockerenv ] || grep -q 'docker\|lxc\|kubepods' /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# GPU detection (priority order)
# ---------------------------------------------------------------------------

detect_gpu() {
    local gpu_type="none"
    local compose_files="-f docker-compose.yml"

    # 1. NVIDIA GPU
    if command -v nvidia-smi &>/dev/null; then
        if nvidia-smi &>/dev/null; then
            gpu_type="nvidia"
            compose_files="-f docker-compose.yml -f docker-compose.gpu-nvidia.yml"
        fi
    fi

    # 2. AMD GPU (only if NVIDIA not found)
    if [ "$gpu_type" = "none" ]; then
        if command -v rocm-smi &>/dev/null && rocm-smi &>/dev/null; then
            gpu_type="amd"
            compose_files="-f docker-compose.yml -f docker-compose.gpu-amd.yml"
        elif command -v amd-smi &>/dev/null && amd-smi &>/dev/null; then
            gpu_type="amd"
            compose_files="-f docker-compose.yml -f docker-compose.gpu-amd.yml"
        fi
    fi

    # 3. Apple Silicon (only if no discrete GPU found)
    if [ "$gpu_type" = "none" ]; then
        local cpu_brand
        cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)
        if echo "$cpu_brand" | grep -qi "Apple"; then
            gpu_type="apple"
            compose_files="-f docker-compose.yml -f docker-compose.apple.yml"
        fi
    fi

    # 4. CPU-only / Intel Mac / Unknown fallback
    # gpu_type already defaults to "none", compose_files to "-f docker-compose.yml"

    echo "$gpu_type" "$compose_files"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    local mode="source"
    if [ "${1:-}" = "--print" ]; then
        mode="print"
    fi

    local cpu_model cpu_cores ram_total os_type
    cpu_model=$(detect_cpu_model)
    cpu_cores=$(detect_cpu_cores)
    ram_total=$(detect_ram_total)
    os_type=$(uname -s)

    local gpu_type compose_files
    read -r gpu_type compose_files <<< "$(detect_gpu)"

    # Warn if running inside a container — fallback to CPU-only
    if is_inside_container; then
        if [ "$mode" = "print" ]; then
            echo "WARNING: Running inside a container. GPU detection may be unreliable."
        fi
        if [ "$gpu_type" != "none" ]; then
            gpu_type="none"
            compose_files="-f docker-compose.yml"
        fi
    fi

    # Always set variables (for source mode) and print assignments (for eval mode).
    # When sourced: variables are set in the calling shell, printed output is harmless.
    # When executed: eval captures the printed output to set variables.
    COMPOSE_FILES="$compose_files"
    GPU_TYPE="$gpu_type"
    CPU_MODEL="$cpu_model"
    CPU_CORES="$cpu_cores"
    RAM_TOTAL="$ram_total"
    OS_TYPE="$os_type"

    if [ "$mode" = "print" ]; then
        case "$gpu_type" in
            nvidia) echo "Detected: NVIDIA GPU" ;;
            amd)    echo "Detected: AMD GPU" ;;
            apple)  echo "Detected: Apple Silicon (Metal)" ;;
            none)   echo "Detected: CPU-only (no supported GPU)" ;;
        esac

        local compose_display="${compose_files//-f /}"
        echo "Compose files: ${compose_display// / + }"
        echo ""
        echo "System Info:"
        echo "  OS:        $os_type"
        echo "  CPU:       $cpu_model"
        echo "  Cores:     $cpu_cores"
        echo "  RAM:       $ram_total"

        if [ "$gpu_type" = "apple" ]; then
            echo ""
            echo "------------------------------------------------------------"
            echo "Apple Silicon notice"
            echo "------------------------------------------------------------"
            echo "Docker Desktop on macOS cannot pass the Apple GPU to Linux"
            echo "containers, and Ollama has no Linux Metal backend. The"
            echo "containerized Ollama will run on CPU only."
            echo ""
            echo "For GPU (Metal) acceleration, run:"
            echo "  task native"
            echo "This starts a native 'ollama serve' on the Mac (Metal) and"
            echo "points the containerized Open WebUI at it via"
            echo "host.docker.internal:11434."
            echo ""
            echo "Prerequisite: install native Ollama first:"
            echo "  brew install ollama"
            echo "  # or: curl -fsSL https://ollama.com/install.sh | sh"
            echo "------------------------------------------------------------"
        fi
    else
        cat <<EOF
COMPOSE_FILES="$compose_files"
GPU_TYPE="$gpu_type"
CPU_MODEL="$cpu_model"
CPU_CORES="$cpu_cores"
RAM_TOTAL="$ram_total"
OS_TYPE="$os_type"
EOF
    fi
}

main "$@"
