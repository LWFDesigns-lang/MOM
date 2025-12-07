# OAuth JIT Security Configuration (December 2025 MCP v2.0)

## 1. AWS Secrets Manager Foundations  
- **Purpose:** Never write OAuth client secrets into `.env` or any source-controlled file (`SETUP_GUIDE_ARCHITECTURE.md:10-216`).  
- **Setup Steps:**  
  1. Create a secure vault per service (e.g., `prod/brave-api-key`, `prod/etsy-api-secret`).  
  2. Store secrets via the AWS CLI:
     ```bash
     aws secretsmanager create-secret \
       --name "prod/brave-api-key" \
       --secret-string "real_key_here"
     ```
  3. Grant your Claude Code runtime IAM permissions to `secretsmanager:GetSecretValue`.  
- **Tip:** Use resource-based policies so only the CLAUDE session can read the secret at runtime.

## 2. OAuth JIT Retrieval Pattern (SEP-835 / SEP-1319)  
```json
{
  "env": {
    "BRAVE_API_KEY_VAULT": "aws-secretsmanager://prod/brave-api-key",
    "BRAVE_OAUTH_TTL": "3600"
  },
  "security": {
    "credential_retrieval": "jit",
    "credential_type": "oauth",
    "token_rotation": true,
    "spec_version": "2.0"
  }
}
```
- **Explanation:** `BRAVE_OAUTH_TTL` enforces a 60-minute TTL (Astrix audited requirement).  
- **Pattern:** Repeat for every OAuth provider listed in `.mcp.json` (Brave, Etsy, Shopify, etc.). Use vault URIs, never literal keys.

## 3. Token Rotation (60-minute TTL)  
- Tokens must auto-refresh at most every 60 minutes; the MCP security block enforces `token_rotation_enabled: true`.  
- Implement a scheduler (Cron, Windows Task Scheduler, or AWS Lambda) to re-fetch secrets and restart your MCP client when TTL expires.  
- Log each refresh in `.claude/data/logs/mcp_calls.jsonl` with `{ "token": "rotated", "timestamp": "..." }`.

## 4. Audit Logging  
- Every MCP invocation must log: timestamp, server name, tool, duration_ms, result (success/failure).  
- Suggested schema (append to `.claude/data/logs/mcp_calls.jsonl`):
  ```json
  {
    "timestamp": "2025-12-07T05:00:00Z",
    "server": "brave-search",
    "tool": "search.listings",
    "status": "success",
    "duration_ms": 312
  }
  ```
- Send failures to `.claude/queues/manual_validation.jsonl` if credentials are missing or invalid.

## 5. Environment File Warnings  
- `.env` files exist for **template** only. Never store production secrets there.  
- Every script that reads `.env` must prepend a warning:
  > `"This file is a placeholder. Real credentials live in AWS Secrets Manager and are injected via MCP JIT retrieval."`  
- `.env` should be listed in `.gitignore` (per architecture guides) and flagged in cleartext in README.

## 6. Astrix & Compliance Notes  
- Astrix security review demands:  
  - **No static keys** (only AWS SM references).  
  - **Hourly rotation** (token_ttl_seconds = 3600).  
  - **Audit trails** for every MCP call.  
- Align `.mcp.json` `security_compliance` block with Astrix requirements (SEP-1024, SEP-835, SEP-986, SEP-1319).  
- Document every compliance decision in `security_config.md` for future audits.

## 7. Troubleshooting  
| Symptom | Likely Cause | Hint |
|---|---|---|
| `credential_retrieval` failing | IAM policy missing `secretsmanager:GetSecretValue` | Attach managed policy `SecretsManagerReadWrite` scoped to the `prod/*` secrets. |
| Tokens expire every minute | TTL set too low | Confirm `*_OAUTH_TTL` env variables are `3600`. |
| Audit log missing entries | Logging middleware skipped | Ensure every MCP call wraps `try/finally` to append to `.claude/data/logs/mcp_calls.jsonl`. |

Use this guide along with [`security_compliance`](.mcp.json:201-231) and the `.env.example` template to enforce zero-knowledge security for the POD automation platform.