# Open WebUI Workspace Imports

Initial Knowledge, Prompts, Skills, Tools, and Model definitions for the **Ollama Portable Assistant** workspace model in Open WebUI.

This is a starter template for a Dockerized Ollama server with an Open WebUI container that assists with coordinating and controlling Ollama access, reading telemetry, and guiding model pulls and cleanup. The workspace model uses attached Knowledge, Skills, and Tools.

---

## Directory Structure

```
open-webui/
├── README.md                  # This file
├── knowledge/                  # Knowledge Base content (manual 2-field creation + file upload)
│   ├── 00-knowledge-bases-index.md   # Index: KB names + descriptions to create
│   ├── 01-portable-guide.md          # How the template fits together
│   ├── 02-model-catalog.md           # Recommended models by hardware tier
│   ├── 03-telemetry-handbook.md      # How to read session telemetry
│   └── 04-import-formats.md          # JSON schemas for Prompts, Skills, Tools, Models
├── prompts/
│   └── prompts.json            # 5 slash-command prompts
├── skills/
│   └── skills.json             # 3 skills (ollama-operator, telemetry-reader, template-guide)
├── tools/
│   └── tools.json              # 7 Python tools (Ollama management)
└── models/
    └── models.json             # 1 workspace model (Ollama Portable Assistant, UI flat-array format)
```

---

## Import Order (Important)

Import in this order. Each step depends on the previous:

1. **Knowledge** — create the 4 KBs and upload content (manual, 2 fields each)
2. **Skills** — import the 3 skills (UI import or API loop)
3. **Tools** — import the 7 tools (UI import or API loop)
4. **Prompts** — import the 5 prompts (UI import or API loop)
5. **Model** — import the workspace model (UI file import), then attach the KBs, Skills, and Tools to it

---

## Step 1: Knowledge Bases (Manual)

Knowledge bases require **two manual fields** (Name + Description) and then a file upload. There is no bulk import endpoint for KBs.

### Create each KB

1. Open Open WebUI at `http://localhost:${WEBUI_HOST_PORT:-3000}`.
2. Go to **Workspace > Knowledge**.
3. Click **+ New Knowledge**.
4. Enter the **Name** and **Description** from [`knowledge/00-knowledge-bases-index.md`](knowledge/00-knowledge-bases-index.md).
5. Click **Create**.

### Upload content into each KB

1. Open the KB you just created.
2. Click **Add Content > Upload File**.
3. Select the markdown file listed under "Upload into this KB" in the index.
4. Wait for processing to complete (the file status turns green).

Repeat for all 4 KBs:

| KB Name | Content File |
| --- | --- |
| Ollama Portable Guide | `knowledge/01-portable-guide.md` |
| Model Catalog | `knowledge/02-model-catalog.md` |
| Telemetry Handbook | `knowledge/03-telemetry-handbook.md` |
| Import Formats & Examples | `knowledge/04-import-formats.md` |

> **Why a 4th KB?** The **Import Formats & Examples** KB surfaces the JSON schemas and minimal examples inside WebUI. When a user asks the assistant "how do I format a Skill?" or "what does a Tool JSON look like?", the model queries this KB and cites the format.

---

## Step 2: Skills (3)

Skills are imported one at a time via `POST /api/v1/skills/create` (there is no bulk `/import` endpoint). The frontend loops over the JSON array and calls `/create` per item.

### Option A: UI Import (recommended for small sets)

1. Go to **Workspace > Skills**.
2. Click **Import**.
3. The UI expects `.md` files with YAML frontmatter. Since `skills/skills.json` is a JSON array, you have two choices:
   - **Convert each skill to a `.md` file** with frontmatter (see below), then import each.
   - **Use the API loop** (Option B) to import the JSON directly.

### Option B: API Loop (recommended)

```bash
# Get your API key from Settings > Account in Open WebUI
API_KEY="your-open-webui-api-key"
WEBUI_URL="http://localhost:${WEBUI_HOST_PORT:-3000}"

python3 -c "
import json, urllib.request

with open('open-webui/skills/skills.json') as f:
    skills = json.load(f)

for skill in skills:
    payload = json.dumps(skill).encode('utf-8')
    req = urllib.request.Request(
        '$WEBUI_URL/api/v1/skills/create',
        data=payload,
        method='POST',
        headers={
            'Authorization': 'Bearer $API_KEY',
            'Content-Type': 'application/json',
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print(f'Created skill: {skill[\"id\"]} -> {resp.status}')
    except Exception as e:
        print(f'Failed skill {skill[\"id\"]}: {e}')
"
```

### Convert a skill to `.md` for UI import (optional)

Each skill in `skills/skills.json` can be saved as a `.md` file with YAML frontmatter:

```markdown
---
name: ollama-operator
description: How to manage models on the local Ollama server...
---

# Ollama Operator Skill
... (the content field) ...
```

The `name` and `description` frontmatter fields auto-populate the skill's name and description on import.

### Skills

| ID | Name | Purpose |
| --- | --- | --- |
| `ollama-operator` | Ollama Operator | How to manage models: list, inspect, pull, delete, status |
| `telemetry-reader` | Telemetry Reader | How to read session telemetry, peaks, and per-model aggregates |
| `template-guide` | Template Guide | How the Taskfile, docker-compose, and scripts fit together |

---

## Step 3: Tools (7)

Tools are Python scripts imported via `POST /api/v1/tools/create` (no bulk endpoint). Each tool's `id` must be a valid Python identifier (alphanumeric + underscore, not starting with a digit).

### Option A: UI Import

1. Go to **Workspace > Tools**.
2. Click **+ New Tool**.
3. For each tool in `tools/tools.json`, paste the `content` (Python source) into the editor, set the Name and ID, and save.

### Option B: API Loop

```bash
API_KEY="your-open-webui-api-key"
WEBUI_URL="http://localhost:${WEBUI_HOST_PORT:-3000}"

python3 -c "
import json, urllib.request

with open('open-webui/tools/tools.json') as f:
    tools = json.load(f)

for tool in tools:
    payload = json.dumps(tool).encode('utf-8')
    req = urllib.request.Request(
        '$WEBUI_URL/api/v1/tools/create',
        data=payload,
        method='POST',
        headers={
            'Authorization': 'Bearer $API_KEY',
            'Content-Type': 'application/json',
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print(f'Created tool: {tool[\"id\"]} -> {resp.status}')
    except Exception as e:
        print(f'Failed tool {tool[\"id\"]}: {e}')
"
```

### Tool IDs

| ID | Name | Purpose |
| --- | --- | --- |
| `ollama_list_models` | Ollama List Models | List pulled models via `/api/tags` |
| `ollama_model_info` | Ollama Model Info | Show model details via `/api/show` |
| `ollama_server_status` | Ollama Server Status | Health check + loaded models via `/api/ps` |
| `ollama_hardware_detect` | Ollama Hardware Detect | Detect GPU and recommend compose config |
| `ollama_recommend_model` | Ollama Recommend Model | Recommend a model by RAM and use case |
| `ollama_pull_model` | Ollama Pull Model | Pull a model via `/api/pull` |
| `ollama_delete_model` | Ollama Delete Model | Delete a model (has confirm gate) |

---

## Step 4: Prompts (5)

Prompts are imported via `POST /api/v1/prompts/create` (no bulk endpoint). Each prompt's `command` must be unique.

### Option A: UI Import

1. Go to **Workspace > Prompts**.
2. Click **+ New Prompt**.
3. For each prompt in `prompts/prompts.json`, fill in the Command, Name, and Prompt Content, then save.

### Option B: API Loop

```bash
API_KEY="your-open-webui-api-key"
WEBUI_URL="http://localhost:${WEBUI_HOST_PORT:-3000}"

python3 -c "
import json, urllib.request

with open('open-webui/prompts/prompts.json') as f:
    prompts = json.load(f)

for prompt in prompts:
    payload = json.dumps(prompt).encode('utf-8')
    req = urllib.request.Request(
        '$WEBUI_URL/api/v1/prompts/create',
        data=payload,
        method='POST',
        headers={
            'Authorization': 'Bearer $API_KEY',
            'Content-Type': 'application/json',
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print(f'Created prompt: /{prompt[\"command\"]} -> {resp.status}')
    except Exception as e:
        print(f'Failed prompt /{prompt[\"command\"]}: {e}')
"
```

### Slash Commands

| Command | Name | Purpose |
| --- | --- | --- |
| `/recommend` | Recommend a Model | Recommend a model by RAM, use case, and GPU |
| `/healthcheck` | Server Health Check | Full health check: API status, pulled, loaded models |
| `/pull` | Pull a Model | Pull a model with size warning and duplicate check |
| `/cleanup` | Clean Up Models | List and remove models with explicit confirmation |
| `/telemetry` | Telemetry Summary | Summarize session telemetry by focus area |

---

## Step 5: Model (1)

The workspace model is imported via the **UI file import** (Workspace > Models > Import). The UI expects a **flat JSON array** of model objects — NOT wrapped in `{"models": [...]}`. The UI loops over the array and calls `createNewModel` per item.

> **Important:** Do not use `POST /api/v1/models/import` with `{"models": [...]}` for UI import. That is the API endpoint format. The UI file importer parses a flat array and loops `createNewModel`. The `models/models.json` file in this repo is already in the correct UI format (a flat array).

### Option A: UI Import (recommended)

1. Go to **Workspace > Models**.
2. Click **Import** (or the ellipsis > Import).
3. Select `models/models.json`.
4. The model "Ollama Portable Assistant" appears in the list.

### Option B: API (per-model create)

```bash
API_KEY="your-open-webui-api-key"
WEBUI_URL="http://localhost:${WEBUI_HOST_PORT:-3000}"

# The UI format is a flat array; loop and call /create per model
python3 -c "
import json, urllib.request

with open('open-webui/models/models.json') as f:
    models = json.load(f)

for model in models:
    payload = json.dumps(model).encode('utf-8')
    req = urllib.request.Request(
        '$WEBUI_URL/api/v1/models/create',
        data=payload,
        method='POST',
        headers={
            'Authorization': 'Bearer $API_KEY',
            'Content-Type': 'application/json',
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print(f'Created model: {model[\"id\"]} -> {resp.status}')
    except Exception as e:
        print(f'Failed model {model[\"id\"]}: {e}')
"
```

### After Import: Attach KBs, Skills, and Tools

The imported model has an empty `knowledge` list and no tool/skill bindings (the import does not link them by name). You must attach them in the UI:

1. Go to **Workspace > Models**.
2. Find **Ollama Portable Assistant** and click **Edit** (pencil icon).
3. **Base Model**: confirm it points at a model you have pulled (default `llama3.2`). Change if you pulled a different one (e.g. `qwen2.5:1.5b`).
4. **Knowledge**: attach the 4 KBs created in Step 1. Click each attached item to toggle retrieval mode:
   - Portable Guide, Model Catalog, Telemetry Handbook -> **Focused Retrieval** (large docs)
   - Import Formats & Examples -> **Focused Retrieval**
5. **Skills**: check all 3 skills (ollama-operator, telemetry-reader, template-guide).
6. **Tools**: check all 7 tools (ollama_list_models, ollama_model_info, ollama_server_status, ollama_hardware_detect, ollama_recommend_model, ollama_pull_model, ollama_delete_model).
7. **Builtin Tools**: ensure **Knowledge Base**, **Skills**, **Time & Calculation**, and **Task Management** categories are enabled (they are by default). These are required for `view_skill` and knowledge tools to work.
8. **Function Calling**: confirm it is set to **Native** (default). Legacy mode breaks skill loading.
9. Click **Save**.

### Hide the Base Model (Optional, Curated Interface)

To give users a clean model picker with only the assistant:

1. Go to **Workspace > Models** (or **Settings > Admin > AI > Models**).
2. Find the base model (e.g. `llama3.2`).
3. Click the ellipsis > **Hide**.
4. The base stays reachable under the hood (the assistant needs it) but disappears from the selector.

---

## Verification

After all imports, verify the setup:

1. Open a new chat and select **Ollama Portable Assistant** as the model.
2. Ask: "What models do I have pulled?" -> the model should call `ollama_list_models`.
3. Ask: "Is the server healthy?" -> the model should call `ollama_server_status`.
4. Ask: "What hardware do I have?" -> the model should call `ollama_hardware_detect`.
5. Ask: "Recommend a model for 8GB RAM coding." -> the model should call `ollama_recommend_model` with ram_gb=8, use_case="coding".
6. Ask: "How do I format a Skill JSON for import?" -> the model should query the Import Formats & Examples KB and cite the schema.
7. Ask: "How does the template work?" -> the model should load the `template-guide` skill via `view_skill` and explain the Taskfile and docker-compose.
8. Type `$` in the chat input -> you should see all 3 skills listed.
9. Type `/` in the chat input -> you should see all 5 prompts listed.

---

## Schema Notes

- **Prompt `command`** must be unique across all prompts.
- **Skill `id`** is lowercased and spaces become hyphens. Must be unique.
- **Skill `name`** must be unique (separate constraint from `id`).
- **Tool `id`** must be a valid Python identifier (`str.isidentifier()`): alphanumeric + underscore, not starting with a digit.
- **Tool `specs`** are auto-derived from the `Tools` class — do not supply them in the form.
- **Tool `meta.manifest` and `meta.has_user_valves`** are overwritten by the server after it loads the Python module. Supply `{}` and `false`.
- **Model UI import expects a flat JSON array**, not `{"models": [...]}`. The UI loops the array and calls `createNewModel` per item. The `{"models": [...]}` shape is for the `/api/v1/models/import` API endpoint, which the UI does not use.
- **Model `id`** must be <=256 chars and unique.
- **Model `meta.tags`** accepts both `["tag1"]` and `[{"name": "tag1"}]` — normalized to the latter on storage.
- **Model `params`** uses `extra='allow'`, so any inference parameter keys are accepted (`temperature`, `top_p`, `function_calling`, etc.).
- **Model `params.function_calling`** must be `"native"` for `view_skill` to work. `"legacy"` breaks skill loading.

---

## Notes

- **Native function calling is required** for `view_skill` to work. The model is configured with `function_calling: "native"`. Do not switch to Legacy.
- **The base model must be pulled** before the workspace model works. Run `task pull -- -m llama3.2` (or your chosen base). The `base_model_id` in `models/models.json` defaults to `llama3.2` — change it in the UI after import if you use a different base.
- **Knowledge is not auto-injected** in native mode. The model must call knowledge tools to retrieve. The system prompt instructs it to do so.
- **Tool `id` values are Python identifiers** (lowercase, underscores). They are validated with `str.isidentifier()` on import.
- **Prompt `command` values must be unique** across all prompts. If you re-import, delete the old prompts first or the import will fail with "Command taken".
- **Skill `name` must be unique**. Re-importing a skill with an existing name will fail with "ID taken".
- **The Import Formats & Examples KB** is what makes the assistant self-documenting inside WebUI. Without it, the model cannot cite the exact JSON schemas when asked.

---

## Updating the Imports

To update any resource, edit the JSON file in this directory and re-import. For models, the UI import upserts (updates existing by `id`) if the model already exists. For prompts, tools, and skills, delete the old one first or use the `/update` endpoint.

---

## Source

The system prompt in `models/models.json` is written for the ollama-portable template: a Gnome Tinkerer assistant that coordinates Ollama access, reads telemetry, and guides model management. It uses the template's Taskfile commands, docker-compose layers, and scripts as its reference material, surfaced through the attached Knowledge bases and Skills.