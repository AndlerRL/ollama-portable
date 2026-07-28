# Telemetry Handbook

The ollama-portable template records session telemetry for every inference call. This handbook explains how to read it.

## Where Telemetry Lives

Session data is stored in `~/.ollama-portable/sessions/` on the host. Each session records:
- CPU and memory snapshots (polled every 2 seconds by `task record`)
- Peak usage during the session
- Duration
- The model used

## Taskfile Commands

| Command | What it does |
|---|---|
| `task record` | Start the background recorder (polls every 2s, writes to `~/.ollama-portable/sessions/`) |
| `task watch` | Live TUI dashboard: container stats, active models, session telemetry |
| `task sessions` | Session history with peak analysis and per-model aggregates |
| `task sessions -- <session_id>` | Drill into a specific session |
| `task status` | Health check + loaded models (quick, non-telemetry) |

## How to Read a Session

A session entry typically shows:
- **Session ID** — timestamped, e.g. `20260717_142030_qwen2.5-1.5b`
- **Model** — which model was running
- **Duration** — how long the session lasted
- **Peak CPU** — the highest CPU percentage observed
- **Peak memory** — the highest RAM usage observed
- **Average tokens/second** — inference speed (if recorded)

## What to Look For

1. **Peak memory close to total RAM** — the model is too large for the host. Recommend a smaller model.
2. **Low tokens/second on CPU** — expected for CPU-only hosts. Recommend a smaller or quantized model, or note that GPU hosts will be faster.
3. **Long load time on first request** — normal. Models stay loaded (`OLLAMA_KEEP_ALIVE=-1`), so subsequent requests are fast.
4. **Memory not releasing after session** — check if the model is still loaded with `task status` (loaded models stay in RAM).
5. **Per-model aggregates** — `task sessions` shows aggregates per model. Compare models to find the best speed/quality tradeoff for the host.

## How to Explain Telemetry to the User

- Lead with the headline: "Your peak memory was X GB out of Y GB total."
- Follow with the implication: "That means model Z fits comfortably."
- End with a recommendation: "You could move up to a larger model if you need better quality."

## Example Interpretation

Session `20260717_142030_qwen2.5-1.5b`:
- Model: qwen2.5:1.5b
- Duration: 4 minutes 12 seconds
- Peak CPU: 87%
- Peak memory: 3.2 GB
- Average tokens/second: 4.1

Interpretation: "Your peak memory was 3.2 GB during a 4-minute qwen2.5:1.5b session. That fits comfortably in 8GB+ RAM. At 4.1 tok/s, this is typical for a 1.5b model on CPU. If you want faster responses, consider qwen2.5:0.5b; if you want better quality and have 16GB+ RAM, try llama3.2:3b."

## What You Do NOT Do

- Do not run `task` commands yourself. You do not have shell access. Tell the user which command to run.
- Do not fabricate telemetry numbers. If you do not have the data, say so and point the user to `task sessions` or `task watch`.
- Do not confuse pulled models (on disk) with loaded models (in RAM). Telemetry is about loaded-model inference.

## Related Tools and Skills

- `ollama_server_status` tool — shows currently loaded models (in RAM)
- `telemetry-reader` skill — load via `view_skill` for the full interpretation framework
- `task watch` — live TUI dashboard for real-time monitoring
- `task sessions` — historical session data with peak analysis