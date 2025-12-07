---
name: pod-design-review
description: Generate five brand-aligned design concepts for validated niches using Claude creativity constrained by deterministic structure and brand voice memories.
version: 1.0.0
mcp_spec_version: "2.0"
triggers: ["create design", "design concepts", "generate designs", "design for *"]
max_tokens: 8000
prerequisites: ["pod-research (GO decision)"]
---

# Design Concept Generation

## When to Use
Invoked after pod-research returns a GO decision with sufficient confidence (≥0.75). Use whenever a validated niche requires new product or listing visuals, especially for LWF Designs or Touge Technicians.

## Execution Flow
1. Load brand voice guidance from `.claude/memories/brand_voice_{brand}.md`.
2. Prompt Claude for five distinct concepts:
   - Each concept must include a unique visual angle, a target sub-audience, a product recommendation, 3-5 hex color palettes, and a clear MidJourney/DALL·E-friendly visual prompt.
3. Evaluate concepts and annotate brand-fit scores (0–1.0). Rank by score.
4. Return top pick plus next recommended step (typically pod-listing-seo).

## Output Format
```json
{
  "niche": "indoor plant care",
  "brand": "LWF",
  "concepts": [
    {
      "id": "concept_1",
      "title": "Monstera Minimalist",
      "visual_prompt": "Clean botanical line drawing of Monstera leaf, soft natural light, minimalist layout, hand-lettered script, eco apparel mockup, studio photograph style",
      "color_palette": ["#2D5016", "#E8F0E8", "#8B9E8F"],
      "target_audience": "Plant parents 25-35 seeking sustainable home goods",
      "recommended_products": ["tee", "mug", "poster"],
      "brand_fit_score": 0.92
    }
  ],
  "top_pick": "concept_1",
  "token_budget": 6000,
  "next_step": "pod-listing-seo"
}
```

## Performance Target
- **Token budget:** 5K–8K per session (Sonnet 4.5).
- **Execution time:** 40–60 seconds per concept batch.
- **Accuracy:** 95% brand adherence through memory-guided prompts.
- **Deterministic guardrails:** Always return exactly five concepts, color palettes, and product recommendations.

## Additional Constraints
- Visual prompts must mention style cues fit for MidJourney or DALL·E (lighting, mood, perspective).
- Product recommendations should map to POD catalog (tee, hoodie, mug, poster, sticker).
- Document assumption when brand voice is ambiguous (e.g., default to LWF with warning).
- Include design rationale referencing brand-specific language (warm+educational for LWF, technical+passionate for Touge).