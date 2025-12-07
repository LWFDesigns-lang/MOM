# Context Optimization Guide

This guide captures the production-ready practices for managing Claude Code 2.0’s expanded 200K window, microcompact mechanics, checkpoints, and efficient workflows. Everything aligns with the December 2025 feature set (microcompact, checkpoints, 200K window, 200K base + optional 1M extension) referenced in CLAUDE.md and the fact-check architecture documents.

## 1. Understanding the 200K Token Window

- **Base allocation:** 200,000 tokens per session (Sonnet 4.5) is the working limit. Everything beyond CLAUDE.md, memories, tool outputs, and active conversation must fit within this window.
- **Budget segments:**
  - CLAUDE.md + memories: ~5K tokens (fixed overhead)
  - Skill definitions + rules: ~10K tokens (loaded when skills chain)
  - Active conversation: ~150K tokens (working space)
  - Response buffer (safety margin): 35K tokens
- **Extended window requests** (1M tokens) require explicit Anthropic approval and are considered only when the workflow cannot be split or checkpointed.

## 2. Microcompact Auto-Cleanup

- **Trigger:** 180K tokens consumed. Auto microcompact runs and removes stale tool outputs while preserving CLAUDE.md and essential memories.
- **Verification:** Run `/context` post-compact to calculate savings. Expect 40%+ reduction (per December 2025 benchmarks).
- **Automation patterns:**
  - Microcompact automatically occurs after ~25-30 skill chains.
  - Scripts (e.g., `.claude/scripts/context-cleanup.sh` and `.ps1`) run `/compact` when tokens reach 180K, after batches, or every 30 operations.
  - Logs recorded to `.claude/data/logs/context.jsonl` include pre/post token counts and compression ratio.
- **Recommendation:** Combine automatic microcompact with manual `/compact` triggered before heavyweight batches.

## 3. Checkpoint & Restore Strategies

- **When to checkpoint:** Always before starting a skill chain, before batch jobs, after GO decisions, prior to major MCP calls, and on user request. Auto checkpoints run every 50K tokens.
- **Naming convention:** `{workflow}_{timestamp}_{description}` (e.g., `validation_20251207_143022_batch5`).
- **Retention:** Keep last 10 checkpoints; prune oldest when max reached. Remove stale ones after 7 days unless tagged as “successful run.”
- **Metadata:** Each checkpoint stores label, token count, and creation timestamp.
- **Restoration priority:** Latest successful checkpoint → last batch checkpoint → user-requested snapshot.
- **Scripts:** `.claude/scripts/checkpoint-manager.{sh,ps1}` provide create/list/restore/delete/auto commands while logging actions to `context.jsonl`.

## 4. Token Budget Management

- **Fixed allocations:** See `.claude/config/context-rules.yaml` for budget breakdown.
- **Workflow budgets:**
  - Single validation: 5K tokens budget, no auto compact unless nearing threshold.
  - Batch validation: 15K tokens with compact/checkpoint after completion.
  - Full pipeline: 40K tokens (research → design → pricing → listing) with enforced microcompact afterward.
- **Enforcement:** Scripts monitor `/context` and write warnings once predictions show <2 batches remaining. Token budgets also tracked via dashboards (e.g., `.claude/scripts/context-manager.sh` outputs percent used and ops remaining).

## 5. Context-Efficient Workflows

- **Minimize redundancy:** Reference `.claude/memories/` instead of copying brand voice into prompts. Use deterministic scripts for repeatable logic.
- **Structured outputs:** Always respond with concise JSON to keep tokens low, allow easy parsing, and avoid verbose reasoning.
- **Checkpoint-aware chaining:** Each chain stage saves checkpoints and logs skill execution/time to `.claude/data/logs/context.jsonl`.
- **Subagent usage:** Spawn subagents when context >60K tokens or when isolation saves ~60% tokens (per fact-check references). Subagents return condensed outputs (~500 tokens) to keep parent context slim.

## 6. Monitoring & Alerting

- **Session telemetry:** `.claude/scripts/session-monitor.{sh,ps1}` instrument session start time, current tokens, tokens/minute, skills executed, MCP calls, checkpoints created, and prediction for time to limit. Logged entries land in `.claude/data/logs/context.jsonl`.
- **Alerts:** Color-coded outputs warn when context surpasses 150K (yellow) and 180K (red). Scripts also track abnormal spikes (token rate exceeding baseline average).
- **Logs:** Every context check, microcompact, checkpoint, cleanup, or session snapshot appends JSON entries to `.claude/data/logs/context.jsonl`.

## 7. Troubleshooting Context Issues

1. **Context approaching 200K:** Run checkpoint-manager to create snapshot; run cleanup script; monitor logs for savings >40%.
2. **Microcompact fails to free tokens:** Verify `/context` still lists high tokens; run manual `/compact`, log savings, consider session reset via `/clear`.
3. **Checkpoints not found:** List `.claude/data/checkpoints/*.meta`. Delete stale ones via checkpoint-manager delete.
4. **Token-ballooned workflow:** Use `context-manager` or `session-monitor` to review token rate; reroute future steps to subagents or reset context.

## 8. Advanced Optimization Techniques

- **Token caching:** Keep reusable data (e.g., brand voice, rules) in files referenced by skills instead of re-sending via prompts.
- **Skill chain batching:** Bundle multiple validations within one checkpointed run to amortize checkpoint overhead (<100 tokens/checkpoint).
- **Microcompact ROI tracking:** Document pre/post storage savings; target 40%+ token reduction to ensure automated cleanup is effective.

## Conclusion

Context optimization requires proactive monitoring, frequent checkpoints, automated microcompact triggers, and token budgeting per workflow. The scripts, configuration files, and templates provided complete the production-ready system mandated by December 2025 Claude Code 2.0 features. Follow this guide, log every metric in `.claude/data/logs/context.jsonl`, and always verify savings before continuing large batches.