---
name: pod-pricing
description: Deterministic Etsy pricing calculator that respects fee structure and margin policies for POD products.
version: 1.0.0
mcp_spec_version: "2.0"
triggers: ["price product", "pricing guidance", "calculate price"]
max_tokens: 1500
---

# Pricing Calculation Skill

## When to Use
Invoke after a validated niche identifies a specific product type (tee, hoodie, mug, etc.) and you need a deterministic price recommendation before listing.

## Execution Flow
1. Gather inputs: `product_type`, optional `custom_cost`, optional `target_margin`, optional list of competitor prices.
2. Run:
   ```bash
   python3 .claude/skills/pod-pricing/scripts/pricing.py <product_type> [custom_cost] [target_margin] [competitor_prices...]
   ```
3. Receive JSON breakdown including fees, margin, .99 pricing, warnings (if any).
4. If margin < 0.25 or > 0.50, log warning and consider manual review.

## Pricing Rules
- Etsy fees total 22.5% (6.5% transaction, 3% payment, 12% ads, 1% regulatory).
- Target margin: ideal 35%, minimum 25%, maximum 50%.
- Base costs (USD):
  - `tee_standard`: 12.50
  - `tee_premium`: 16.00
  - `hoodie`: 28.00
  - `mug`: 8.50
  - `poster_12x18`: 12.00
  - `poster_18x24`: 18.00
  - `sticker_3x3`: 2.50
- Pricing formula: `price = cost / ((1 - fees) * (1 - margin))`, rounded down to `.99` strategy.
- Include competitor comparison, flagging prices >20% above/below average.

## Output Format
```json
{
  "product_type": "tee_standard",
  "base_cost": 12.5,
  "recommended_price": 34.99,
  "price_range": {
    "min": 29.99,
    "max": 48.75
  },
  "margin_achieved": 0.35,
  "breakdown": {
    "cost": 12.50,
    "etsy_fees": 7.86,
    "profit": 14.63
  },
  "warnings": []
}
```

## Performance Target
- Token budget: 100–150 tokens per calculation.
- Execution time: <5 seconds (local deterministic script).
- Accuracy: Deterministic margin enforcement with 35% target.
- Deterministic guardrails: No LLM calls inside script.