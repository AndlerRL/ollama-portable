# Ollama Portable Guide

The ollama-portable template is a Dockerized Ollama server with a Taskfile-driven CLI and an optional Open WebUI container. Batteries included — no Python, no manual installs, just Docker and `task`.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (Docker Desktop or Engine)
- [Task](https://taskfile.dev/installation/) (`brew install go-task` on macOS)

## The Two Containers

| Container | Image | Port | Purpose |
|---|---|---|---|
| `ollama_server` | `ollama/ollama:latest` | `11434` | The inference server |
| `open_webui` | `ghcr.io/open-webui/open-webui:main` (custom build) | `3000` | ChatGPT-like UI (optional, `task webui`) |

The WebUI Dockerfile pre-downloads the `all-MiniLM-L6-v2` embedding model at build time to avoid first-start download delay.

## Hardware Detection

The template auto-detects the host GPU and picks the right Docker Compose configuration:

| GPU | Detection | Compose files |
|---|---|---|
| NVIDIA | `nvidia-smi` found | `docker-compose.yml` + `docker-compose.gpu-nvidia.yml` |
| AMD | `rocm-smi` or `amd-smi` found | `docker-compose.yml` + `docker-compose.gpu-amd.yml` |
| Apple Silicon | `sysctl` reports Apple CPU | `docker-compose.yml` (Metal via Ollama built-in) |
| CPU-only | None of the above | `docker-compose.yml` |

All `docker compose` commands route through `scripts/compose.sh`, which sources `scripts/detect.sh`. No manual configuration needed. Run `task detect` to see what was detected.

## Taskfile Commands

| Command | Description |
|---|---|
| `task boot` | Start server + pull a model (interactive menu or `--model`) |
| `task up` | Start all services |
| `task webui` | Start server with Open WebUI on `:3000` |
| `task down` | Tear down everything (removes volumes) |
| `task stop` | Stop services (keeps volumes) |
| `task reboot` | Tear down and boot fresh |
| `task reload` | Tear down and restart all services |
| `task pull -- -m <model>` | Pull a model into the running container |
| `task list` | List all pulled models |
| `task rm -- -m <model>` | Remove a model |
| `task run -- -m <model>` | Start interactive chat with a model |
| `task show -- -m <model>` | Show model details (size, params, template) |
| `task status` | Health check + loaded models |
| `task logs` | Tail server logs (`--lines 100` for more) |
| `task backup` | Backup models volume to a tar.gz |
| `task restore -- <file>` | Restore models from a backup |
| `task record` | Start background session recorder (CPU/memory per inference) |
| `task watch` | Live TUI dashboard (container stats, models, session telemetry) |
| `task sessions` | Session history with peak analysis and model aggregates |
| `task detect` | Detect host hardware and show recommended configuration |

## Model Selection Flags

All model-aware commands support these flag formats:

```bash
task boot -- -m deepseek-r1:1.5b
task pull -- --model=llama3.2
task run -- -m mistral
```

Omit the flag for an interactive prompt.

## Data Persistence

`task down` removes Docker volumes — all models, chats, and settings are lost. Destructive commands auto-backup before running:

| Command | Auto-backup tag | Auto-restore |
|---|---|---|
| `task down` | `pre-down` | — |
| `task reboot` | `pre-reboot` | Yes (on next boot) |
| `task reload` | `pre-reload` | Yes (immediately) |

Backups include both volumes: `ollama_storage` (models) and `open_webui_data` (chats, settings).

Manual backup/restore:

```bash
task backup -- --tag my-setup
task restore -- ollama_backup_my-setup.tar.gz
```

## Configuration

Copy `.env.example` to `.env` and customize:

```env
OLLAMA_HOST_PORT=11434    # Host port for Ollama API
WEBUI_HOST_PORT=3000      # Host port for Open WebUI
```

## Cloud Models (Optional)

To use Ollama cloud models (GPT-4, Claude, etc.), authenticate inside the container:

```bash
docker exec -it ollama_server ollama login
```

Follow the prompts to authenticate with your Ollama account. Cloud models will then appear in the WebUI model selector.

## Architecture

```
ollama-portable/
├── .env.example
├── docker-compose.yml            # CPU-only base (ollama_server + open_webui)
├── docker-compose.gpu-nvidia.yml # NVIDIA GPU override
├── docker-compose.gpu-amd.yml    # AMD GPU override
├── Dockerfile.webui              # Pre-cached embedding model
├── Taskfile.yaml                 # 17 tasks
├── LICENSE
└── scripts/
    ├── init.sh                   # Boot with model selection
    ├── pull.sh                   # Pull any model
    ├── list.sh                   # List pulled models
    ├── rm.sh                     # Remove a model
    ├── run.sh                    # Interactive chat
    ├── show.sh                   # Model details
    ├── status.sh                 # Health check
    ├── logs.sh                   # Tail server logs
    ├── backup.sh                 # Backup both volumes
    ├── restore.sh                # Restore both volumes
    ├── detect.sh                 # Hardware detection
    ├── compose.sh                # Detection-aware compose wrapper
    ├── record.sh                 # Session recorder daemon
    ├── watch.sh                  # Live TUI dashboard
    └── sessions.sh               # History + peak analysis
```

## How to Explain the Template

- Lead with the two-container architecture (Ollama + optional WebUI).
- Mention hardware auto-detection — users do not need to pick a compose file manually.
- Point to `task detect` for hardware, `task boot` to start, `task webui` for the UI.
- Warn that `task down` removes volumes; `task stop` keeps them.
- For telemetry, point to `task record`, `task watch`, and `task sessions`.