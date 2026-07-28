# Open WebUI Knowledge Bases — Setup Index

This file lists the Knowledge Bases to create manually in Open WebUI. Each KB requires two fields: **Name** and **Description**. After creating each KB, upload the corresponding content file(s) listed under "Upload into this KB".

---

## KB 1 — Ollama Portable Guide

- **Name:** `Ollama Portable Guide`
- **Description:** `How the ollama-portable template fits together: the two containers, hardware auto-detection, Taskfile commands, data persistence, and configuration. The assistant cites this when explaining how the template works.`
- **Upload into this KB:** `01-portable-guide.md`

## KB 2 — Model Catalog

- **Name:** `Model Catalog`
- **Description:** `Recommended Ollama models by hardware tier (CPU, Apple Silicon, NVIDIA, AMD) and use case (general, coding, reasoning, vision, small). Includes expected tokens/second and pull commands. The assistant cites this when recommending models.`
- **Upload into this KB:** `02-model-catalog.md`

## KB 3 — Telemetry Handbook

- **Name:** `Telemetry Handbook`
- **Description:** `How to read the ollama-portable session telemetry: CPU/memory snapshots, peak usage, per-model aggregates, and the TUI dashboard. The assistant cites this when explaining performance or resource usage.`
- **Upload into this KB:** `03-telemetry-handbook.md`

## KB 4 — Import Formats & Examples

- **Name:** `Import Formats & Examples`
- **Description:** `The JSON schemas and minimal examples for importing Prompts, Skills, Tools, and Models into Open WebUI, plus the Knowledge Base manual-creation format. The assistant cites this when asked how to build or import a resource.`
- **Upload into this KB:** `04-import-formats.md`

---

## How to create each KB

1. Open Open WebUI at `http://localhost:3000`.
2. Go to **Workspace > Knowledge**.
3. Click **+ New Knowledge**.
4. Enter the **Name** and **Description** exactly as listed above.
5. Click **Add Content > Upload File** and select the markdown file listed under "Upload into this KB".
6. Wait for file processing to complete (status turns green).
7. Repeat for each KB.

After all four KBs exist, attach them to the **Ollama Portable Assistant** model in **Workspace > Models > Edit > Knowledge**.