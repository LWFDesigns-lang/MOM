# POD Automation Guide

## Overview
This guide documents the full automation infrastructure built inside `d:/MOM`. It details how subagents, workflows, fallbacks, token monitoring, and documentation come together to keep POD operations 95% automated while ensuring recoverability and compliance.

## Architecture Summary
- **Head:** `CLAUDE.md` defines the brain and context rules.
- **Subagents:** Fresh-context workers (`validation-specialist`, `design-reviewer`, `price-advisor`) enforce insulated execution (each file under `.claude/agents/`).
- **Workflows:** Headless scripts (`daily-niche-discovery.sh/ps1`, `batch-validation.sh/ps1`, `full-pipeline.sh`) execute in cron or scheduler, produce logs/results in `.claude/data/`.
- **Fallbacks:** `.claude/config/fallbacks.json` defines primary→secondary chains (`get_etsy_count`, `get_trend_score`, `validate_niche`) plus global retry/log settings.
- **Token Management:** `.claude/config/token-budgets.yaml` + `.claude/scripts/token-monitor.js` enforce budgets; dashboards available via `.claude/scripts/usage-dashboard.sh`.
- **Resilience:** Each workflow includes checkpoints, rollback hooks, exit-code handling, and token-aware logging. Fallback executor logs to `.claude/data/logs/fallbacks.jsonl`.

## Subagent Spawn Decision Tree
1. **Batch (≥3 niches)** → spawn `validation-specialist` per niche.
2. **Low Confidence (<0.75)** → trigger `validation-specialist` or `price-advisor`.
3. **Design review required (≥3 concepts or uncertain brand)** → spawn `design-reviewer`.
4. **Large context (>60K tokens)** → reroute to `validation-specialist` for fresh context.
5. **Price change >15% or margin uncertain** → invoke `price-advisor`.

Each subagent returns structured JSON (<500 tokens) to minimize parent session bloat.

## Workflow Instructions

### 1. Daily Niche Discovery
- **Purpose:** Run headless validation of 5 trending concepts.
- **Script:** `.claude/workflows/daily-niche-discovery.sh` (bash) and `.ps1` variant.
- **Key Steps:** create logs/results dir, run Claude headless prompt, save JSON, count GO decisions.
- **Cron:** e.g., `0 7 * * * /bin/bash d:/MOM/.claude/workflows/daily-niche-discovery.sh`.

### 2. Batch Validation
- **Purpose:** Validate batches of niches (uses subagents for isolation).
- **Script:** `.claude/workflows/batch-validation.sh` (bash) + PowerShell version.
- **Usage:** `./batch-validation.sh -i niches.txt`; configurable `WORKERS`.
- **Enforcement:** token budget 2.5K/niche; failures flag exit to stop pipeline.
- **Outputs:** aggregated report `batch_validation_*.json`.

### 3. Full Pipeline
- **Purpose:** Research → design → pricing → listing pipeline with checkpoints.
- **Script:** `.claude/workflows/full-pipeline.sh`.
- **Flow:** sequential prompts to each skill (`pod-research`, `pod-design-review`, `pod-pricing`, `pod-listing-seo`) with strict JSON outputs, checkpointing, rollback handling.
- **Token Budget:** 8-12K tokens total.

## Fallback Chain Behavior
1. **Primary:** Preferred MCP/tool (e.g., `data-etsy`, `data-trends`, `logic-validator`).
2. **Secondary:** Alternative MCP or cache (Playwright, local cache files).
3. **Tertiary:** Cache hit with `max_age_hours`; `heuristic` estimation if needed.
4. **Quaternary:** Heuristic methods reduce confidence.
5. **Final:** Escalate to queue (manual lookup/validation).
6. **Logging:** `.claude/scripts/fallback-executor.js` logs to `.claude/data/logs/fallbacks.jsonl` with penalties, escalation entries.

## Token Budget Management
- Budgets defined in `.claude/config/token-budgets.yaml`.
- `token-monitor.js` tracks per workflow/session usage; budgets enforcement triggers actions (warning/exceeded).
- Daily reports written to `.claude/data/logs/tokens_YYYYMMDD.json`.
- Dashboard script (`usage-dashboard.sh`) prints usage, budget, warning, and cost projection.

## Troubleshooting & Recovery
- **Rollback:** `full-pipeline.sh` checkpoints each stage; failures log stage and call `rollback`.
- **Fallbacks:** `fallback-executor.js` handles retries, logs warnings, escalates as needed.
- **Token Alerts:** Token monitor warns/exits when budgets breached; dashboard surfaces warnings.
- **Cron Integration:** All scripts log exit codes; cron can email on non-zero exit.

## Monitoring & Alerting
- Logs stored under `.claude/data/logs/`.
- Use `tail -f` on the relevant `workflow_*.log` files for live debugging.
- Fallbacks logged to `.claude/data/logs/fallbacks.jsonl`.
- Dashboard script surfaces current day consumption and budget hits.

## Example Automation Sequence
1. Cron runs daily discovery script → logs + JSON results → triggers `validation-specialist`.
2. Operator reviews `.claude/data/results/niches_*.json`; good niches feed into `batch-validation`.
3. `batch-validation` spins subagents per niche, enforcing 2.5K token cap.
4. Winning niche runs through `full-pipeline.sh` for design/pricing/listing.
5. Any MCP failure triggers fallback chain; logs appended and escalation queue updated.
6. Token monitor keeps budgets in check; run `usage-dashboard.sh` for snapshot.

## Scheduling Tips
- Schedule PowerShell scripts via Task Scheduler on Windows; Bash variants on Linux cron.
- Run `claude` headless prompts using `--output-format json` to simplify parsing.
- Daily use `usage-dashboard.sh` to confirm budgets before running heavy workflows.

## Change Management
- Update `.claude/config/token-budgets.yaml` + `.claude/scripts/token-monitor.js` when adding new workflows.
- Add new subagents/workflows to automation guide to keep documentation aligned.
- Always keep `CLAUDE.md` references consistent with script behavior (context resets, checkpoints, budgets).

## Review & Maintenance
- Regularly inspect `.claude/data/logs/fallbacks.jsonl` for fallback frequency.
- Archive `validated_niches` entries every 100 records to `.claude/data/archive`.
- Keep `plugin.json` and `.mcp.json` aligned with new subagents/workflows if this system is packaged as a plugin.
