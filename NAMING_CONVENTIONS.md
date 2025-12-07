# Naming Conventions

## Files and Directories
- Lowercase with hyphens for directories and files (e.g., `pod-research`, `config-name.yaml`).
- Scripts: `action-name.sh` or `action-name.js`.
- Configuration: `config-name.yaml`/`json`.

## Skills
- Skill names: `{domain}-{action}` (e.g., `pod-research`, `pod-pricing`).
- Skill files: `SKILL.md` per skill root; scripts in `scripts/{action}.py`.
- Prompts: `prompts/{template-name}.md`.

## MCP Servers
- Server names: `{category}-{purpose}` (e.g., `data-etsy`, `logic-validator`).
- MCP tools: snake_case verbs (`get`, `search`, `validate`, `calculate`).

## Data and Logs
- Brand voice: `brand_voice_{brand}.md`.
- Validated data: `validated_{entity}.json`.
- Logs: `mcp_calls.jsonl`, `api_usage.jsonl`, `errors_{YYYYMMDD}.log`.
- Checkpoints: `YYYYMMDD_{operator}_{batch##}_{stage}`.

## Variables and Code
- Environment variables: ALL_CAPS_SNAKE_CASE with service prefix (e.g., `ETSY_API_KEY`).
- JSON keys: snake_case; booleans use `is_`/`has_`/`should_` prefixes.
- Python functions: snake_case; JavaScript functions: camelCase; classes: PascalCase.
