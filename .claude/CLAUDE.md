# POD Automation Brain (Claude Code 2.0)

## Identity
- **Brands:** LWF Designs (eco/mindful) + Touge Technicians (JDM performance)
- **Goal:** 95% automated POD niche research → design → pricing → listing.
- **Automation Model:** Single Claude Pro Sonnet 4.5 session with skill chains and deterministic guards.

## Five-Layer Architecture
1. **Layer 1 – Brain:** Claude Code orchestrator with Antigravity context, `/checkpoint`, `/compact`, and microcompact cleanup.
2. **Layer 2 – Skills:** pod-research, pod-design-review, pod-pricing, pod-listing-seo, memory-manager; deterministic-first scripts + LLM creativity where noted.
3. **Layer 3 – MCP Servers:** Tier 1/2 verified (filesystem, brave-search, perplexity, playwright, qdrant, neo4j, etsy, shopify) invoked via `.mcp.json`.
4. **Layer 4 – Data & Memory:** `.claude/memories/` for brand voice and validated_niches; `.claude/data/` for archives; `.claude/queues/` for review.
5. **Layer 5 – Automation:** Hooks, skill chains, plugin manifest + queue escalation ensure GO decisions persist and low confidence results escalate.

## Context Management Rules
- **Token window:** 200K per session base; auto-microcompact at ~180K frees ~80K tokens.
- **Checkpoints:** Create after each GO decision + listing publish (e.g., `/checkpoint "After 5 validations"`). Use `/restore` when rerunning design/pricing.
- **Session lifecycle:** Reset after ~30 skill chains, reload CLAUDE.md + memories; rely on context management instructions (200K ceiling, microcompact, explicit `/context` if needed).
- **Token budgets:** Documented per skill (1.5K-2.5K for research, 5K-8K for design, 100-150 for pricing, 4K-6K for listing, ~0.5K-0.9K for memory writes).

## File Locations
- `.claude/skills/...` – Skill definitions + scripts.
- `.claude/memories/` – Brand voice + validated niches.
- `.claude/hooks/post-skill-complete.json` – Post-skill automation.
- `.claude/chains/` – Skill chain YAMLs.
- `.claude/data/` – Skip archives.
- `.claude/queues/review_queue.jsonl` – Escalation queue.
- `plugin.json` – Plugin manifest referencing skills/chains/hooks/memory.
- `.mcp.json` – MCP server configuration.

## Decision Framework
- Deterministic-first: Python scripts handle GO/SKIP, pricing, validation, SEO scoring, memory writes.
- LLM usage confined to creative design + listing copy (pod-design-review, pod-listing-seo) with brand voice references.
- Confidence checks: <0.75 triggers review queue via hooks, GO results saved via memory-manager.
- Scripts log warnings if inputs fall outside thresholds; escalate to human review when margins exceed guardrails.

## What NOT to Do
- ❌ Do not hardcode API keys or store them in `.env`; all credentials retrieved via AWS Secrets Manager (JIT).
- ❌ Do not skip deterministic validation before running design/listing.
- ❌ Do not exceed documented token budgets; rely on microcompact + checkpoints.
- ❌ Do not let LLM handle business logic (GO/SKIP, pricing, SEO compliance, memory persistence).
- ❌ Do not mutate memory JSON manually outside automated hooks, except for curated audits (>90 days archive, top 100 per brand).