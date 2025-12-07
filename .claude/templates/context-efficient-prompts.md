# Context-Efficient Prompt Templates

A curated library of token-minimal prompt patterns for high-frequency operations. Each template references cached data and uses structured requests so Claude Code can stay under the 200K window while maximizing deterministic logic.

## 1. Niche Validation Template (Minimal Open Context)
```md
Validate niche: {niche}

Data references:
- `memory:validated_niches` for past decisions
- `.claude/memories/brand_voice_{brand}.md` for tone

Instructions:
1. Use deterministic thresholds (Etsy <50K, Trends >=40).
2. Run `.claude/skills/pod-research/scripts/validate.py` with gathered counts.
3. Return compact JSON (go/skip, tokens_used, brand_assignment, warnings[]).

Output must be:
{
  "niche": "string",
  "decision": "GO"|"SKIP",
  "confidence": 0.0-1.0,
  "etsy_count": number,
  "trend_score": number,
  "reasoning": ["concise emojis"],
  "brand_assignment": "LWF"|"Touge"|"Either",
  "warnings": []
}
```

## 2. Design Review Template (Reference Brand Memory)
```md
Design review for niche: {niche}
Brand: {brand}

Context:
- Load `.claude/memories/brand_voice_{brand}.md`.
- Reference recent `validated_niches` entry (GO only).

Ask:
1. Generate 3 concepts with title, color palette, product mix.
2. Use JSON arrays only.
3. Mention token budget (max 1500 tokens).

Output example:
{
  "niche": "...",
  "brand": "...",
  "concepts": [
    { "id": "concept_1", "title": "...", "color_palette": ["#hex"], "alignment": "concise" }
  ],
  "top_pick": "concept_2",
  "next_step": "pod-listing-seo"
}
```

## 3. Listing Generation Template (Cache Friendly)
```md
Create listing copy utilizing:
- `memory:design_result`
- `memory:price_result`
- `.claude/memories/brand_voice_{brand}.md`

Structure:
1. Title (<=140 chars)
2. 13 tags (JSON array)
3. Description (300+ words, keywords front-loaded)
4. SEO score (calc via `.claude/skills/pod-listing-seo/scripts/validate_seo.py`)

Return:
{
  "listing": { "title": "...", "tags": [...], "description": "...", "seo_score": 0.0-1.0 },
  "alternatives": { "titles": ["..."], "reasoning": "short rationale" }
}
```

## 4. Cache-Friendly Status Template
Use the following when referencing cached results:
```md
Context snapshot:
- Checkpoint: {checkpoint_label}
- Tokens used: {current_tokens}
- Skills executed: {skills_count}
- Logs updated: `.claude/data/logs/context.jsonl`

Instruction:
"Summarize last checkpoint actions without re-describing tool outputs."
```
This prevents duplicates and reduces context churn.

## 5. Compressed Instruction Format
When issuing automation instructions:
```md
[Task] {short task label}
[Context] {reference file path}
[Budget] {token budget}
[Output] JSON only, schema names explicit
```
This structure keeps prompts consistent, easy to scan, and friendly to the 200K window.