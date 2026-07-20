# ollama-portable

Dockerized Ollama server with a Taskfile-driven CLI for pulling, running, and managing models. Batteries included — no Python, no manual installs, just Docker and `task`.

## Quick Start

```bash
# Clone
git clone https://github.com/andlerrl/ollama-portable.git
cd ollama-portable

# Copy and customize config (optional)
cp .env.example .env

# Boot the server and pull a model
task boot
```

That's it. The server is running on `http://localhost:11434`.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (Docker Desktop or Engine)
- [Task](https://taskfile.dev/installation/) (`brew install go-task` on macOS)

## Commands

| Command | Description |
|---|---|
| `task boot` | Start server + pull a model (interactive menu or `--model`) |
| `task up` | Start all services |
| `task webui` | Start server with Open WebUI (ChatGPT-like interface on `:3000`) |
| `task down` | Tear down everything (removes volumes) |
| `task stop` | Stop services (keeps volumes) |
| `task reboot` | Tear down and boot fresh |
| `task reload` | Tear down and restart all services |
| `task pull -- -m llama3.2` | Pull a model into the running container |
| `task list` | List all pulled models |
| `task rm -- -m llama3.2` | Remove a model |
| `task run -- -m llama3.2` | Start interactive chat with a model |
| `task show -- -m llama3.2` | Show model details (size, params, template) |
| `task status` | Health check + loaded models |
| `task logs` | Tail server logs (`--lines 100` for more) |
| `task backup` | Backup models volume to a tar.gz |
| `task restore -- ollama_backup_20260717.tar.gz` | Restore models from a backup |
| `task record` | Start background session recorder (CPU/memory per inference) |
| `task watch` | Live TUI dashboard (container stats, models, session telemetry) |
| `task sessions` | Session history with peak analysis and model aggregates |
| `task detect` | Detect host hardware and show recommended configuration |

### Model selection

All model-aware commands support these flag formats:

```bash
task boot -- -m deepseek-r1:1.5b
task pull -- --model=llama3.2
task run -- -m mistral
```

Omit the flag for an interactive prompt.

## Hardware Detection

The project auto-detects your GPU and selects the right Docker Compose configuration:

```bash
# Check what hardware you have
task detect
```

| GPU | Detection | Compose files |
|---|---|---|
| NVIDIA | `nvidia-smi` found | `docker-compose.yml` + `docker-compose.gpu-nvidia.yml` |
| AMD | `rocm-smi` or `amd-smi` found | `docker-compose.yml` + `docker-compose.gpu-amd.yml` |
| Apple Silicon | `sysctl` reports Apple CPU | `docker-compose.yml` (Metal via Ollama built-in) |
| CPU-only | None of the above | `docker-compose.yml` |

All `docker compose` commands in the Taskfile route through `scripts/compose.sh`, which sources `detect.sh` to pick the right override files. No manual configuration needed.

## Monitoring

Track CPU, memory, and session history for every inference call:

```bash
# Start the background recorder (polls every 2s)
task record

# Live TUI dashboard — container stats, active models, session telemetry
task watch

# View session history with peak analysis and per-model aggregates
task sessions

# Drill into a specific session
task sessions -- 20260717_142030_qwen2.5-1.5b
```

Session data is stored in `~/.ollama-portable/sessions/`. Each session records CPU/memory snapshots, peak usage, and duration — useful for comparing model performance and identifying resource bottlenecks.

For bare-metal Ollama users, check out **[dst0/watch-ollama](https://github.com/dst0/watch-ollama)** — a Python-based TUI with GPU monitoring and systemd integration.

## Configuration

Copy `.env.example` to `.env` and customize:

```env
OLLAMA_HOST_PORT=11434    # Host port for Ollama API
WEBUI_HOST_PORT=3000      # Host port for Open WebUI
```

## Architecture

```
ollama-portable/
├── .env.example           # Configuration template
├── docker-compose.yml     # ollama_server + open_webui (opt-in)
├── Taskfile.yaml          # All commands
└── scripts/
    ├── init.sh            # Boot with model selection
    ├── pull.sh            # Pull any model
    ├── list.sh            # List pulled models
    ├── rm.sh              # Remove a model
    ├── run.sh             # Interactive chat
    ├── show.sh            # Model details
    ├── status.sh          # Health check
    ├── logs.sh            # Tail server logs
    ├── backup.sh          # Backup volume
    └── restore.sh         # Restore volume
```

## Related

This repo runs the Ollama inference server. For the full AI agent stack (fine-tuning, pipelines, multi-model orchestration), see **[andlerrl/ai-agents-server](https://github.com/andlerrl/ai-agents-server)**.

## License

MIT — see [LICENSE](LICENSE)
