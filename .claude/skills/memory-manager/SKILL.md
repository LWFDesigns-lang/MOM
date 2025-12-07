---
name: memory-manager
description: Persist validated niches and learnings across sessions with deterministic retention rules.
version: 1.0.0
mcp_spec_version: "2.0"
triggers: ["save learning", "remember this", "update memory"]
max_tokens: 1200
---

# Memory Persistence

## When to Use
Activated whenever pod-research emits a GO decision or when users explicitly request saving a design/pattern. Ensures deterministic storage for later recall.

## Execution Flow
1. On pod-research GO:
   - Append the full result to `.claude/memories/validated_niches.json`.
   - Respect 90-day archive rule and cap per category (top 100 by confidence).
2. On pod-research SKIP:
   - Archive to `.claude/data/skipped_niches.json` for pattern spotting (no auto-influence yet).
3. Provide query docs for standard shells (`jq`, `grep`) referencing stored files.
4. Trigger cleanup: remove entries older than 90 days and keep highest confidence 100 per brand.

## Output Format
```json
{
  "niches": [
    {
      "niche": "indoor plant care",
      "decision": "GO",
      "confidence": 0.85,
      "etsy_count": 18500,
      "trend_score": 62,
      "brand": "LWF",
      "date_validated": "2025-12-07",
      "notes": null
    }
  ]
}
```

## Performance Target
- Token budget: 500–900 per memory write.
- Deterministic accuracy: 100% writes when GO, archive SKIP.
- Cleanup: Auto-archive entries older than 90 days, limit 100 per brand by highest confidence.
- Query guidance: CLI examples included within SKILL.md for future use.