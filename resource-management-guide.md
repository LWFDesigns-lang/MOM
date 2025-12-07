# Resource Management Guide

This guide outlines the policies and procedures for managing the resources that underpin the POD automation platform: Docker containers (Qdrant, Neo4j), MCP servers, disk/memory usage, API quotas, cost tracking, and backup/recovery. It pairs automation-ready diagnostics with human checkpoints to keep the system resilient.

## 1. Docker Container Management

- **Services covered:** Qdrant (vector memory), Neo4j (graph), any database/cache layers supporting Claude Code.
- **Startup:** Use `docker run` commands with localhost-only bindings. Example:
  ```bash
  docker run -d --rm --name qdrant-pod \
    -p 127.0.0.1:6333:6333 \
    -v qdrant-pod-storage:/qdrant/storage \
    -e QDRANT_API_KEY=${QDRANT_API_KEY} \
    qdrant/qdrant:latest
  ```
- **Monitoring:** Run `docker stats qdrant-pod neo4j-pod` daily. Automate via cron/Task Scheduler and alert if CPU >70% or memory >80%.
- **Restart policy:** On failure, use `docker logs` to triage, then `docker restart <name>`. Capture exit code and log to `.claude/data/logs/context.jsonl`.
- **Storage cleanup:** Schedule `docker volume prune` weekly (with human approval). Keep snapshots of Qdrant/Neo4j data before pruning.

## 2. MCP Server Resource Limits

- **Quota awareness:** Each MCP has request rate limits. Document per server in `resource-management-guide.md`.
- **MCP health:** Use `.claude/scripts/mcp-health-check.sh/.ps1` before major workflows. Ensure 0 failed connections before batches.
- **MCP logging:** Log each MCP invocation (timestamp, tool, status) to `.claude/data/logs/context.jsonl`. Use this log to correlate with spikes in tokens or cost.
- **Failover:** If a Tier 2 MCP fails, reroute to a fallback (cache, deterministic script) and log the failover path. Escalate to manual queue if no fallback remains.

## 3. Disk Space Planning

- **Critical paths:** `.claude/data/logs/`, `.claude/data/results/`, `.claude/data/checkpoints/`.
- **Monitoring:** Run `du -sh .claude/data` weekly. If usage exceeds 2GB, rotate old logs:
  - Compress older logs: `tar -czf logs_$(date +%F).tar.gz .claude/data/logs/*`
  - Move archives to `d:/MOM/.claude/data/archive/`
- **Thresholds:** Alert when disk usage reaches 85% of available space. Use `fsutil volume diskfree c:` on Windows to query free bytes.

## 4. Memory Usage Monitoring

- **Process monitoring:** If running local services (Claude CLI, MCP servers), track RAM per process (`tasklist /FI "IMAGENAME eq node.exe"`). Document high-water marks in logs.
- **Memory budgeting:** Reserve at least 2GB for Claude/Node combined on Windows. Write failover instructions if memory pressure emerges (restart Docker containers or signal workforce to pause).
- **Garbage collection:** For long-running sessions, restart Claude CLI every 30 skill chains (per context rules) to release heap memory.

## 5. API Rate Limit Handling

- **Token pool:** Each MCP uses OAuth tokens rotating every 60 minutes. Monitor usage via log metrics (MCP calls per minute).
- **Rate limit detection:** Parse MCP responses for HTTP 429 (or rate-limit semantics). On detection:
  1. Backoff for 60s.
  2. Switch to cache/deterministic fallback if safe.
  3. Log incident to `.claude/data/logs/context.jsonl`.
- **Circuit breaker:** After 3 consecutive rate-limit responses, pause the offending workflow and notify the operator via summary log or external alert.

## 6. Cost Optimization Strategies

- **Token spend vs ROI:** Track token spend per workflow in `.claude/data/logs/context.jsonl`. Highlight high ROI chains (e.g., validations at 2.5K tokens vs manual research at 10K).
- **Automated alerts:** When microcompact savings drop below 40%, emit warning—means context got bloated.
- **MCP usage:** Prefer deterministic MCPs (logic-validator) for decisions. Reserve LLM-heavy MCPs for creative tasks only, limiting token cost.
- **Docker cost:** Spin containers only during active work (start before job, stop after). Use `docker stop` once batch complete.

## 7. Backup Procedures

- **Critical files:** `.claude/config/*.json`, `.claude/memories/`, `.claude/scripts/`, `.claude/data/checkpoints/`.
- **Backup cadence:** Snapshot once daily via Git commit + remote push and weekly zipped archive:
  ```bash
  backup_dir=".claude/backups/$(date +%F)"
  mkdir -p "$backup_dir"
  rsync -av .claude/data/checkpoints "$backup_dir/checkpoints"
  cp -r .claude/config "$backup_dir/config"
  ```
- **Storage:** Keep backups on separate drive or remote storage (AWS S3). Ensure they are encrypted.

## 8. Recovery Protocols

- **Context recovery:** Use checkpoint-manager restore if workflows fail or tokens saturated. Document restoration event in `.claude/data/logs/context.jsonl`.
- **Docker recovery:** If Qdrant/Neo4j fail, pull latest data from backup (`docker cp` from archive) before restarting.
- **Credential recovery:** Rotate AWS Secrets Manager tokens if connection fails; ensure `CLAUDE.md` instructs operators to run `claude /mcp` to validate after rotation.
- **Post-recovery runbook:**
  1. Run session-monitor to confirm token rate.
  2. Execute context-manager snapshot.
  3. Resume workflows from most recent checkpoint.

This guide, paired with the context optimization docs and scripts, ensures the Claude-based platform uses every token, container, and dollar efficiently while remaining recoverable after unexpected events.