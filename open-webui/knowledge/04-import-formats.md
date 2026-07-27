# Import Formats & Examples

Open WebUI workspace resources are imported via JSON (Prompts, Skills, Tools, Models) or manual creation + file upload (Knowledge). This document is the in-WebUI reference for each format, with minimal examples the assistant model can cite when a user asks how to build or import a resource.

## Resource Types at a Glance

| Resource | Format | Import Method | Bulk Import? |
|---|---|---|---|
| Knowledge | Markdown / any file | Manual KB creation (Name + Description) + file upload | No |
| Prompt | JSON (PromptForm) | POST /api/v1/prompts/create (loop) | No |
| Skill | JSON (SkillForm) or .md with frontmatter | POST /api/v1/skills/create (loop) or UI .md import | No |
| Tool | JSON (ToolForm, Python source) | POST /api/v1/tools/create (loop) | No |
| Model | JSON (flat array of ModelForm) | UI file import (loops createNewModel) or POST /api/v1/models/create (loop) | No (UI); API has /import but UI does not use it |

## Knowledge Base

A Knowledge Base is created in the UI with two fields:

- **Name** (required)
- **Description** (required)

After creating the KB, you upload files into it. Files can be markdown, PDF, plain text, code, or any text-based document. No frontmatter is required in the file — the Name and Description live on the KB itself, not in the file.

Retrieval modes (toggled per attached KB on the model):
- **Focused Retrieval (default):** RAG chunks and indexes the file. The model calls knowledge tools to retrieve relevant chunks. Best for large docs.
- **Full Context:** Injects the entire file into every message. Best for short, always-relevant reference docs.

Example KB content file (markdown):

```markdown
# Model Catalog

## CPU-only, <16GB RAM
- qwen2.5:0.5b — 3-10 tok/s
- llama3.2:1b — 3-10 tok/s
```

## Prompt (PromptForm)

Schema:

```json
{
  "command": "recommend",
  "name": "Recommend a Model",
  "content": "Recommend an Ollama model for {{ram_gb | number:required}} GB RAM and use case {{use_case | select:options=[\"General\",\"Coding\"]:required}}.",
  "data": {},
  "meta": {"description": "What this prompt does"},
  "tags": ["ollama", "models"]
}
```

Fields:
- `command` (required, unique): the slash command string, e.g. `recommend`
- `name` (required): display name
- `content` (required): the prompt body with `{{variable}}` placeholders
- `data` (optional): structured prompt parameters
- `meta` (optional): metadata, e.g. `{"description": "..."}`
- `tags` (optional): list of bare strings

Variable types: `text`, `textarea`, `select`, `number`, `checkbox`, `date`, `datetime-local`, `color`, `email`, `range`, `tel`, `time`, `url`, `month`, `map`. Add `:required` to make a field mandatory. System variables like `{{CURRENT_DATE}}`, `{{USER_NAME}}` are auto-replaced.

Import: loop POST /api/v1/prompts/create, one request per prompt. No bulk endpoint.

## Skill (SkillForm)

Schema:

```json
{
  "id": "ollama-operator",
  "name": "Ollama Operator",
  "description": "How to manage models on the local Ollama server.",
  "content": "# Ollama Operator Skill\n\nFull markdown instructions here. Loaded on demand via view_skill.",
  "meta": {"tags": ["ollama", "models"]},
  "is_active": true
}
```

Fields:
- `id` (required): lowercased, spaces become hyphens, must be unique
- `name` (required): must be unique (separate constraint from id)
- `description` (optional): shown in the manifest; the model uses it to decide whether to call `view_skill`
- `content` (required): full markdown instructions
- `meta.tags` (optional): list of bare strings
- `is_active` (optional, default true): inactive skills are excluded from manifests

How the model uses it: only `name` + `description` are injected by default (the manifest). The model calls `view_skill("ollama-operator")` to load the full `content` on demand. This requires native function calling.

Import: loop POST /api/v1/skills/create, or save `content` as a .md file with YAML frontmatter (`name:`, `description:`) and use the UI .md import.

## Tool (ToolForm)

Schema:

```json
{
  "id": "ollama_list_models",
  "name": "Ollama List Models",
  "content": "\"\"\"\nTitle: Ollama List Models\nDescription: List pulled models.\n\"\"\"\n\nimport urllib.request, json, os\n\nclass Tools:\n    def list_models(self) -> str:\n        base_url = os.environ.get(\"OLLAMA_BASE_URL\", \"http://ollama_server:11434\")\n        with urllib.request.urlopen(f\"{base_url}/api/tags\", timeout=10) as resp:\n            return resp.read().decode(\"utf-8\")\n",
  "meta": {
    "description": "List pulled models via /api/tags",
    "manifest": {},
    "has_user_valves": false
  }
}
```

Fields:
- `id` (required): must be a valid Python identifier (`str.isidentifier()`): alphanumeric + underscore, not starting with a digit. Gets lowercased.
- `name` (required): display name
- `content` (required): raw Python source. Must define a `Tools` class with callable methods. OpenAPI specs are auto-derived from the class — do not supply `specs`.
- `meta.description` (optional): what the tool does
- `meta.manifest` (optional): supply `{}` — the server overwrites it after loading the module
- `meta.has_user_valves` (optional): supply `false` — the server detects `UserValves` in the source

Import: loop POST /api/v1/tools/create, one request per tool. No bulk endpoint.

## Model (ModelForm, UI flat-array format)

The UI file importer expects a **flat JSON array** of model objects — NOT wrapped in `{"models": [...]}`. The UI loops over the array and calls `createNewModel` per item.

Schema (flat array):

```json
[
  {
    "id": "ollama-portable-assistant",
    "base_model_id": "llama3.2",
    "name": "Ollama Portable Assistant",
    "meta": {
      "description": "Shown in the model selector",
      "profile_image_url": null,
      "capabilities": {
        "file_context": false,
        "vision": false,
        "file_upload": true,
        "web_search": true,
        "image_generation": false,
        "code_interpreter": true,
        "terminal": false,
        "citations": true,
        "status_updates": true,
        "usage": true,
        "memory": true,
        "builtin_tools": true
      },
      "knowledge": [],
      "suggestion_prompts": [
        {"title": "What models do I have?", "content": "List pulled models."}
      ],
      "tags": [{"name": "ollama"}],
      "defaultFeatureIds": ["web_search", "code_interpreter"]
    },
    "params": {
      "system": "You are the Ollama Portable Assistant.",
      "temperature": 0.3,
      "top_p": 0.9,
      "function_calling": "native",
      "stream_response": true
    },
    "is_active": true
  }
]
```

Fields:
- `id` (required): unique, <=256 chars
- `base_model_id` (required for custom models): must reference a pulled model
- `name` (required): display name
- `meta.description` (optional): shown in the selector
- `meta.profile_image_url` (optional): null, a URL, or a base64 data URL
- `meta.capabilities` (optional): toggle file_context, vision, file_upload, web_search, image_generation, code_interpreter, terminal, citations, status_updates, usage, memory, builtin_tools
- `meta.knowledge` (optional): list of attached KBs — linked in the UI after import, not by name in the JSON
- `meta.suggestion_prompts` (optional): list of `{title, content}` starter chips
- `meta.tags` (optional): accepts both `["tag"]` and `[{"name": "tag"}]` — normalized to the latter
- `meta.defaultFeatureIds` (optional): feature IDs to enable by default, e.g. `["web_search", "code_interpreter"]`
- `params.system` (optional): the system prompt. Supports `{{ USER_NAME }}`, `{{ CURRENT_DATE }}`, `{{ USER_GROUPS }}`.
- `params.temperature`, `top_p`, etc. (optional): any inference parameter keys (extra keys allowed)
- `params.function_calling` (optional): `"native"` (default, required for `view_skill`) or `"legacy"`
- `is_active` (optional, default true)

Import: UI file import (Workspace > Models > Import) parses the flat array and loops `createNewModel`. Do NOT use `POST /api/v1/models/import` with `{"models": [...]}` for UI import — that is the API endpoint format, which the UI does not use.

After import, attach KBs, Skills, and Tools in the UI: **Workspace > Models > Edit**. The JSON import does not link them by name.

## Import Order

1. Knowledge (manual, 2 fields each + file upload)
2. Skills (loop /create)
3. Tools (loop /create)
4. Prompts (loop /create)
5. Model (UI file import), then attach KBs/Skills/Tools in the UI

## Key Rules

- **Native function calling is required** for `view_skill` to work. Set `params.function_calling: "native"`.
- **Tool `id` must be a Python identifier.** `ollama_list_models` is valid; `ollama-list-models` is rejected.
- **Prompt `command` must be unique.** Re-importing without deleting fails with "Command taken".
- **Skill `name` must be unique.** Re-importing without deleting fails with "ID taken".
- **Model UI import expects a flat array**, not `{"models": [...]}`. The `{"models": [...]}` shape is for the `/api/v1/models/import` API endpoint, which the UI does not use.
- **Knowledge is not auto-injected** in native mode. The model must call knowledge tools to retrieve. Instruct it in the system prompt.
- **Tool `specs` are auto-derived** from the `Tools` class. Never supply `specs` in the form.
- **Model `meta.knowledge` is linked in the UI**, not by name in the JSON. The import only creates the model shell.