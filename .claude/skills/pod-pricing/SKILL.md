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
1. Gather inputs: JSON string with required `product_type`.
2. Run:
   ```bash
   python3 .claude/skills/pod-pricing/scripts/pricing.py '{"product_type": "t-shirt"}'
   ```
3. Receive JSON breakdown including recommended price, minimum price, and cost/fee breakdown.
4. Use minimum price when you need to meet the documented minimum margin thresholds.

## Pricing Rules
- Supported `product_type` keys and base costs (USD):
  - `t-shirt`: 12.00
  - `hoodie`: 25.00
  - `mug`: 8.00
  - `poster`: 10.00
  - `sticker`: 3.00
  - `tote-bag`: 15.00
- Etsy fees total 22.5% (`total_percent`), plus fixed payment/listing components baked into the calculation.
- Recommended price uses a markup multiplier per product: `t-shirt` 2.0, `hoodie` 1.8, `mug` 2.5, `poster` 2.2, `sticker` 3.0, `tote-bag` 2.0. The multiplier is applied to base cost and rounded to `.99` for storefront consistency.
- Minimum price is calculated from the margin floor per product (40–60% range) using `price = cost / (1 - min_margin - fee_percent)`, then rounded to `.99`.
- Profit margin shown is based on the markup-derived recommended price; use the minimum price when strict margin floors are required.
- Note: The markup multipliers above replaced the older "cost divided by (1 - fees) and (1 - margin)" formula for the recommended price so the JSON fields now mirror the implemented multiplier-first strategy.

## Output Format
```json
{
  "product_type": "t-shirt",
  "base_cost": 12.0,
  "recommended_price": 24.99,
  "minimum_price": 32.99,
  "profit_margin_percent": 29.5,
  "cost_breakdown": {
    "production": 12.0,
    "platform_fees_estimate": 5.62,
    "profit_at_recommended": 7.37
  }
}
```

## Performance Target
- Token budget: 100–150 tokens per calculation.
- Execution time: <5 seconds (local deterministic script).
- Accuracy: Deterministic margin enforcement with 35% target.
- Deterministic guardrails: No LLM calls inside script.