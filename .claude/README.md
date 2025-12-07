# .claude/ Directory Structure

This directory holds all Claude Code 2.0 configuration, skills, servers, and runtime data for the POD automation system.

## Layout
```
.claude/
├─ CLAUDE.md               # Brain configuration (never remove)
├─ skills/                 # Core automation skills (research, pricing, SEO)
├─ mcp-servers/            # Custom MCP implementations (data-etsy, data-trends, logic-validator)
├─ workflows/              # Automation workflows
├─ scripts/                # Utility + maintenance scripts
├─ config/                 # Configuration files
├─ memories/               # Persistent brand/business data
├─ hooks/                  # Post-execution hooks
├─ queues/                 # Escalation queues
├─ templates/              # Reusable templates
└─ data/                   # Runtime data (logs, results, checkpoints, archives)
```

## Maintenance (home/local)
- Keep `.env` locally (gitignored) with API keys and service passwords.
- Restart services after updating `.env` using `.claude/scripts/start-services.sh`.
- Check `.claude/data/logs` for errors; rotate or clean as needed.

## Getting Started
1. Create a `.env` file (copy `.env.example`) with local credentials.
2. Read `CLAUDE.md` for brain configuration.
3. Explore `skills/` for available automations.
4. Use `scripts/` for maintenance (`start-services.sh`, optional `rotate-credentials.sh`).
