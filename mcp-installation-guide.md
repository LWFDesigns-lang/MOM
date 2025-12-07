# MCP Installation Guide — POD Automation (Dec 2025 MCP v2.0)

## Prerequisites
1. **Node.js 20.x** (LTS) — required for MCP packages (per SETUP_GUIDE_ARCHITECTURE.md:262-272).
2. **Python 3.11+** — used by deterministic scripts (see fact-check docs for helper scripts).
3. **Docker Desktop (latest)** — runs Qdrant & Neo4j containers. Ensure virtualization enabled.
4. **AWS CLI (latest)** — for Secrets Manager operations.
5. **Claude Code CLI** — used to install plugin and run chains (`claude /mcp`, `claude plugin install`).

## Environment Setup
```powershell
# Clone repository and enter workspace
git clone <repo-url> d:/MOM
cd d:/MOM

# Copy placeholder env (Windows PowerShell)
Copy-Item .env.example .env
```
> ⚠️ Populate secrets via AWS Secrets Manager and map vault URIs in `.mcp.json` (`security-config.md`).

## Install MCP Packages (exact versions from architecture references)
```powershell
npm install @anthropic-ai/mcp-server-filesystem@^1.0.0 `
  @anthropic-ai/mcp-server-brave-search@^1.0.0 `
  perplexity-mcp@^1.0.0 `
  @anthropic-ai/mcp-server-playwright@^1.0.0 `
  qdrant-mcp@^1.0.0 `
  neo4j-mcp@^1.0.0 `
  etsy-mcp@^1.0.0 `
  shopify-mcp@^1.0.0
```
> Ensures compliance with MCP v2.0 version pins (SETUP_GUIDE_ARCHITECTURE.md:261-273).

## Docker Services
```powershell
# Start Qdrant + Neo4j (both localhost-only)
docker-compose up -d
```
> Qdrant binds to `127.0.0.1:6333`, Neo4j to `127.0.0.1:7687/7474`. Volumes persist data (`docker-compose.yml`).

## Verification Steps
1. **Validate .mcp.json**  
   ```powershell
   node -e "JSON.parse(require('fs').readFileSync('.mcp.json','utf8'))"
   ```
   - Expect no errors; ensures JSON schema compliance.

2. **Check MCP Servers**  
   ```powershell
   claude /mcp
   ```
   - Should show each server listed with `✅ connected`.

3. **Health Checks**
   ```powershell
   curl http://127.0.0.1:6333/health
   curl http://127.0.0.1:7474
   ```
   - Expect Qdrant `{"status":"ok"}` and Neo4j greeting page.

4. **Run health script (PowerShell-friendly)**  
   ```powershell
   bash .\mcp-health-check.sh
   ```
   - Reports file, JSON, binaries, Docker status, and credential reminders.

## Version Compatibility Matrix
| Component | Version Constraint | Notes |
|-----------|--------------------|-------|
| Node.js | 20.x (LTS) | Required for MCP CLI packages. |
| Python | 3.11+ | Used by scripts (pod-research, fallback executor). |
| Docker | Latest | Ensures latest Qdrant/Neo4j images (localhost binding). |
| MCP Spec | 2.0 (Nov 2025) | Enforces stdio invocation, OAuth-only (SEP-1024/835/986/1319). |
| MCP Packages | `@anthropic-ai/*` ^1.0.0, `perplexity-mcp` ^1.0.0, `qdrant-mcp` ^1.0.0, `neo4j-mcp` ^1.0.0, `etsy-mcp` ^1.0.0, `shopify-mcp` ^1.0.0 | Matches architecture references (fact-check doc). |

## Troubleshooting
- **MCP servers not connecting:**  
  - Re-run `node_modules/.bin/<server> --help` to confirm executable exists.  
  - Ensure AWS Secrets Manager vault URIs are reachable; check IAM permissions.

- **Docker containers stuck/stopped:**  
  - `docker-compose logs qdrant neo4j` for errors.  
  - Free ports (6333, 7687) if already in use (use `netstat -ano | findstr 6333`).

- **Token errors in logs:**  
  - Rotate secrets manually via AWS CLI if TTL expired (60 minutes).  
  - Check `security-config.md` and `.mcp.json` `security_compliance` block.

- **Environment warnings:**  
  - `.env` should only include placeholders; real keys pulled via JIT.

## Next Steps
1. Run `.claude/scripts/mcp-health-check.sh`.  
2. Start Claude Code session and execute Phase 2 chains.  
3. Monitor `.claude/data/logs/mcp_calls.jsonl` for audit entries.