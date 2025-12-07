# Pod Design Review Style Guide

## Purpose
Provide Claude with structured brand rules to keep design prompts aligned with LWF Designs and Touge Technicians voice + visuals. Use this guide when generating the five design concepts.

## Brand Voice Lookup
- LWF: `.claude/memories/brand_voice_lwf.md`
- Touge: `.claude/memories/brand_voice_touge.md`

## Prompt Structure
1. **Context:** Provide validated niche, GO decision, and brand assignment.
2. **Brands:** Inject relevant brand voice excerpt above (tone, audience, what to avoid).
3. **Design Deliverables:**
   - Title describing concept.
   - Visual prompt (MidJourney/DALL·E ready, lighting, perspective, mood).
   - 3–5 hex color palette.
   - Target sub-audience + product recommendation(s).
   - Brand-fit score reasoning.
4. **Additional Constraints:**
   - Avoid non-PODable items (no NFTs, services).
   - Mention eco/technical cues based on brand.

## Example Snippet
```
Niche: Indoor plant care (GO via pod-research)
Brand: LWF Designs (warm, eco, educational tone)

Prompt:
- Visual: "Soft botanical photography, golden hour lighting, layered with organic textures, minimalist line art overlay, natural fibers focus"
- Products: tee_standard, mug, poster_12x18
- Colors: ["#2D5016", "#E8F0E8", "#8B9E8F"]
- Audience: Health-conscious plant parents 25-35
- Brand-fit: Describe how the tone keeps messaging educational, approachable, and not sales-y.
```

## Token Budget
- 5,000–8,000 tokens
- Prefer concise instructions; reference brand memory via short bullet points.

## Failure Modes
- If brand ambiguous, default to LWF and call out assumption.
- Flag and re-run if any concept lacks color palette or product mapping.