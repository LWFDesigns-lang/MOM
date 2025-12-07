# Workflow Efficiency Best Practices

This template distills workflow-level optimization strategies so operators consistently sequence skills, decide on subagents, and maximize cache/microcompact benefits.

## 1. Skill Chain Sequencing

```md
[Chain Name] {workflow label}
[Steps]
1. pod-research (deterministic validation)
2. checkpoint (label: {workflow}_pre_design)
3. pod-design-review
4. pod-pricing
5. pod-listing-seo
6. checkpoint (label: {workflow}_complete)

[Budget] 8-12K tokens
[Notes] Only proceed to design if pod-research → GO. Inline reasoning must be <=3 bullet points.
```

- Always checkpoint before batch-critical steps (design, pricing, publish).
- Trigger microcompact after full pipelines or when tokens >160K.

## 2. Subagent Decision Matrix

```md
[When to spawn subagent]
- Batch size ≥ 3 niches → spawn validation-specialist per niche
- Confidence < 0.75 on any skill result → dispatch price-advisor
- Parent context > 60K tokens → spawn design-reviewer for fresh context
- High-risk workflow (new brand, complex product) → subagent for isolation

[Fallback]
- Collect condensed JSON from subagent
- Append to parent context via memory reference (e.g., memory:subagent_result)
```

- Subagents return ~500 tokens, reducing parent context by ~60%.
- Use memory references or `.claude/data/results/` files instead of re-injecting entire discussions.

## 3. Batch Operation Optimization

- Combine similar tasks (e.g., validating 5 niches) inside one checkpointed session.
- Use `context-manager` script to monitor tokens every 5 minutes, ensuring budgets stay under 25K for batches.
- Log GO counts to `.claude/data/logs/context.jsonl`.

## 4. Cache Utilization Strategy

- Reference `memory` entries rather than rewriting brand voice each run.
- Store repetitive prompts in `.claude/templates/context-efficient-prompts.md`.
- Use `.claude/data/cache/*.json` for precomputed competitor data, loading via deterministic scripts.

## 5. Memory Reference Patterns

- After each task, append minimal metadata to `.claude/memories/validated_niches.json`.
- When referencing past outcomes, supply only the pointer (e.g., `memory:validated_niches[-1]`) inside prompts.
- Keep `stateful context` small by summarizing results in 3-4 tokens per entry (like “GO, 0.85 confidence, LWF”).

Consistently following these templates keeps the Claude Code session light, compliant with the 200K ceiling, and ready for microcompact, checkpoint, and cleanup automation.