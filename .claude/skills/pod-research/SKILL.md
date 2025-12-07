---
name: pod-research
description: Validate POD niches using deterministic Etsy competition, trends, and brand cues to return a binary GO/SKIP decision.
version: 1.0.0
mcp_spec_version: "2.0"
triggers: ["validate niche", "research niche", "check niche", "is * viable"]
max_tokens: 2500
confidence_threshold: 0.75
---

# POD Research & Validation

## When to Use
Use whenever a new niche or product idea is introduced. Automatically triggered by niche validation requests, especially when assessing Etsy competition, trend stability, and brand-fit.

## Execution Flow
1. Gather measured inputs: Etsy listing count, 12-month Google Trends score (with direction), optional brand hint.
2. Invoke deterministic script:
   ```bash
   python3 .claude/skills/pod-research/scripts/validate.py \
     "niche name" <etsy_count:int> <trend_score:int> [trend_direction] [brand_hint]
   ```
3. Evaluate returned JSON:
   - Decision must be GO/SKIP with confidence.
   - At confidence <0.75, escalate to review queue via hooks.
   - GO decisions trigger downstream design/pricing/listings.

## Validation Criteria
- Etsy listing count < 50,000 for GO; >100,000 triggers automatic SKIP.
- Google Trends score ≥40 required; ≥60 earns bonus confidence.
- Trend direction rising adds confidence; declining with low score forces SKIP.
- Brand assignment based on keyword matching (LWF vs Touge) or provided hint.
- Sub-niche suggestions derived from modifiers for discovery.
- Token budget: 1,500-2,500 per validation (Claude Sonnet 4.5).

## Output Format
```json
{
  "niche": "indoor plant care",
  "decision": "GO",
  "confidence": 0.85,
  "etsy_count": 18500,
  "trend_score": 62,
  "trend_direction": "rising",
  "reasoning": [
    "✅ Etsy: 18,500 listings (ideal range 5K-30K)",
    "🔥 Trends: 62/100 (strong/growing)",
    "📈 Trend direction: Rising (bonus confidence)"
  ],
  "brand_assignment": "LWF",
  "sub_niches": [
    "indoor plant care + eco-friendly",
    "indoor plant care + beginner",
    "indoor plant care + affordable"
  ],
  "warnings": []
}
```

## Performance Target
- Token cost: 1.5K–2.5K (parallel MCP results + summarization).
- Execution time: <30 seconds (Brave Search + Perplexity data retrieval).
- Accuracy: 99% deterministic GO/SKIP decisioning.
- Confidence thresholds documented for automated escalation (<0.75) and review queue insertion.