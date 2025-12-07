---
name: pod-listing-seo
description: Generate SEO-compliant Etsy listing copy with deterministic validation of title, tags, description, and brand voice integration.
version: 1.0.0
mcp_spec_version: "2.0"
triggers: ["create listing", "write copy", "etsy copy for *", "listing for *"]
max_tokens: 6000
---

# Listing SEO Generation

## When to Use
Invoke after design concepts are approved (pod-design-review) and pricing is set. Called when Etsy listing text must be drafted with brand-aligned tone and SEO compliance.

## Execution Flow
1. Load brand voice from `.claude/memories/brand_voice_{brand}.md`.
2. Prompt Claude to generate:
   - Title (≤140 chars, keyword front-loaded, brand tone, max 62 for Etsy limit reminder).
   - Exactly 13 tags composed of long-tail phrases.
   - 300+ word description with primary keywords in first 160 characters.
3. Run deterministic validation via `.claude/skills/pod-listing-seo/scripts/validate_seo.py`.
4. Return SEO score + warnings for title length, tag count, description compliance.
5. Low score (<0.8) triggers manual review or re-run.

## Requirements
- **Title:** ≤140 characters, priority keyword at start, brand voice mention, no all caps.
- **Tags:** Exactly 13 tags mixing broad and long-tail (no duplicates).
- **Description:** ≥300 words, includes keywords in first 160 characters, brand tone, call-to-action aligned with brand rules.
- **Brand voice:** Reference `.claude/memories/brand_voice_{brand}.md`.
- **Token budget:** 4,000–6,000 tokens (Sonnet 4.5).
- **Output:** JSON with title, tags array, description, seo_score (0–1), warnings, related design/pricing references.

## Output Format
```json
{
  "niche": "indoor plant care",
  "brand": "LWF",
  "listing": {
    "title": "Eco Plant Care Tee – Sustainable Gift for Houseplant Lovers",
    "tags": ["plant lover gift", "... (13 total)"],
    "description": "300+ word SEO-friendly copy with keywords in first 160 characters...",
    "seo_score": 0.88,
    "warnings": []
  }
}
```

## Performance Target
- **Token cost:** 4K–6K tokens per listing pipeline.
- **Execution time:** <45 seconds (Claude call + validation).
- **Accuracy:** ≥97% compliance for title length/tags/description keywords.
- **Deterministic guardrails:** Validation script ensures counts/lengths and warns on deviations.