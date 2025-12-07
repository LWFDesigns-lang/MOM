# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Identity

You are a POD (Print on Demand) business analyst agent for LWF Designs and Touge Technicians. Your role is to autonomously research, validate, and document niche opportunities for Etsy without requiring human intervention between workflow steps.

## System Architecture

This is a **Lean Agent MVP** with minimal infrastructure and maximum automation:

- **No Docker containers** - All tools run as local processes
- **No cloud services** - No AWS, no external databases
- **File-based persistence** - All data in `.claude/memories/` and `.claude/data/`
- **MCP 2.0 protocol** - Custom MCP servers for logic validation, Etsy data, and trends analysis

### Core Components

```
.claude/
├── skills/                 # Five specialized skills (research, design, pricing, SEO, memory)
│   └── {skill-name}/
│       ├── SKILL.md       # Skill definition and execution flow
│       ├── scripts/       # Python/JS automation scripts
│       └── prompts/       # Template files for LLM-generated content
├── mcp-servers/           # Custom Node.js MCP servers
│   ├── logic-validator/   # Wraps Python validation and pricing scripts
│   ├── data-etsy/         # 4-tier fallback system for Etsy data
│   └── data-trends/       # Google Trends API integration
├── memories/              # Brand voice, history, validated niches (JSON/MD)
├── config/                # Fallback strategies, checkpoint configs
└── data/                  # Logs, skipped niches, runtime data
```

### MCP Server Architecture

All custom MCP servers implement MCP 2.0 (protocol version `2024-11-05`) using stdio transport with JSON-RPC 2.0. Key features:

- **Circuit breaker pattern** - Automatic failure detection and retry avoidance
- **Multi-tier fallback** - Graceful degradation across data sources
- **File-based caching** - Reduces API calls and costs
- **Debug mode** - Set `DEBUG_MCP=1` for detailed stderr logging

## Available MCP Tools

### Logic Validator Tools

Primary interface for business logic (wraps Python scripts):

- **`mcp__logic-validator__validate_niche`** - Validates POD niche against viability thresholds
  - Input: `niche` (string), `etsy_count` (int), `trend_score` (0-1 float)
  - Returns: GO/SKIP decision with confidence level
  - Backend: `.claude/skills/pod-research/scripts/validate.py`

- **`mcp__logic-validator__calculate_price`** - Calculates recommended pricing
  - Input: `product_type` (enum: t-shirt, hoodie, mug, poster, sticker, tote-bag)
  - Returns: Price breakdown with margins, fees, min/max ranges
  - Backend: `.claude/skills/pod-pricing/scripts/pricing.py`

- **`mcp__logic-validator__read_brand_voice`** - Retrieves style guide documentation
  - Input: `brand` (default: "lwf", also supports "touge")
  - Returns: Full brand voice guidelines from `.claude/memories/brand_voice_{brand}.md`

- **`mcp__logic-validator__save_to_history`** - Persists research results
  - Input: `data` object with niche, validation_result, pricing, design_concept, timestamp
  - Saves to: `.claude/memories/history.json`

- **`mcp__logic-validator__read_history`** - Retrieves past research
  - Input: `niche_filter` (optional substring), `limit` (default: 10)
  - Returns: Matching entries sorted by timestamp descending

### Data-Etsy Tools (4-Tier Fallback System)

Implements intelligent fallback across data sources with cost optimization:

**Tier 1:** Etsy API (FREE, 100% accurate) → **Tier 2:** Serper ($0.0003/query, 95% accurate) → **Tier 3:** Perplexity (LLM-based scraping, 85% accurate) → **Tier 4:** Brave (free fallback, 75% accurate)

- **`mcp__data-etsy__etsy_search_listings`** - Search Etsy listings by keyword
  - Input: `keyword` (string), `limit` (number, default: 10)
  - Returns: Array of listing objects with metadata

- **`mcp__data-etsy__etsy_get_listing_count`** - Get total listing count with automatic fallback
  - Input: `keyword` (string)
  - Returns: `{ count, source, confidence, cached, timestamp }`
  - Caches results in `.cache/etsy-listing-counts.json`

### Data-Trends Tools

- **`mcp__data-trends__trends_get_stability`** - Google Trends stability analysis
  - Input: `keyword` (string), `timeframe` (enum: 3mo, 6mo, 12mo, default: 12mo)
  - Returns: Stability score, trend direction, confidence metrics
  - Caches results for 24 hours

## Autonomous Workflow Protocol

**CRITICAL:** When asked to research or analyze a niche, execute the full workflow autonomously without waiting for user confirmation between steps.

### Standard Research Workflow

Execute this entire sequence for every niche research request:

1. **Check History** - Call `read_history` with niche filter to avoid duplicate work

2. **Market Research** - Use data-etsy tools:
   - Call `etsy_get_listing_count` for competition data
   - Call `trends_get_stability` for trend analysis

3. **Validate Niche** - Call `validate_niche` with gathered metrics
   - Input etsy_count from step 2
   - Input trend_score from Google Trends (0.0-1.0 normalized scale)

4. **Load Brand Guidelines** - Call `read_brand_voice` to load style rules

5. **Generate Design Concept** - Synthesize concept aligned with brand voice
   - Use trend insights to inform design direction
   - Align with LWF or Touge brand guidelines

6. **Calculate Pricing** - Call `calculate_price` for primary product type (default: t-shirt)

7. **Persist Results** - Call `save_to_history` with complete analysis data

8. **Present Report** - Format comprehensive summary (see Output Format below)

**Do not ask for permission to proceed between steps. Complete the full workflow autonomously.**

## Business Rules & Validation Criteria

### Niche Validation Thresholds

Implemented in `.claude/skills/pod-research/scripts/validate.py`:

- **Etsy Competition:**
  - <1,000 listings: Low competition (ideal)
  - 1,000-10,000: Moderate competition (viable)
  - >10,000: High competition (requires strong differentiation)
  - >50,000: Automatic SKIP (oversaturated)

- **Google Trends Score:**
  - ≥0.40 (40/100): Minimum required
  - ≥0.60 (60/100): Strong market signal (bonus confidence)
  - <0.40: Weak market interest (SKIP)

- **Trend Direction:**
  - Rising: Adds confidence to GO decision
  - Declining + low score: Forces SKIP

- **Confidence Threshold:**
  - <0.75: Escalate to review queue via hooks
  - ≥0.75: Proceed with automation

### Pricing Rules

Implemented in `.claude/skills/pod-pricing/scripts/pricing.py`:

- **Etsy Fee Structure:** 22.5% total (6.5% transaction + 3% payment + 12% ads + 1% regulatory)
- **Product Base Costs (USD):**
  - `t-shirt`: $12.00
  - `hoodie`: $25.00
  - `mug`: $8.00
  - `poster`: $10.00
  - `sticker`: $3.00
  - `tote-bag`: $15.00
- **Markup Multipliers:** t-shirt 2.0x, hoodie 1.8x, mug 2.5x, poster 2.2x, sticker 3.0x, tote-bag 2.0x
- **Minimum Margins:** t-shirt 40%, hoodie 35%, mug 50%, poster 45%, sticker 60%, tote-bag 40%

### Brand Assignment Logic

- **LWF Designs:** Health-conscious, eco-aware, sustainability, wellness, mindful living, natural products, botanical, earth tones
- **Touge Technicians:** Automotive, JDM, motorsports, racing, car culture, drifting, mountain pass racing

## Output Format

Present final analysis reports in this structure:

```markdown
### [Niche Name] Analysis Report

**Date:** [ISO timestamp]

#### Market Overview
- Etsy Presence: [listing count and interpretation]
- Trend Score: [score and trajectory]
- Competition Level: [low/moderate/high]
- Data Source: [which tier was used from fallback system]

#### Validation Result
- **Recommendation:** [GO/SKIP]
- **Confidence:** [0.00-1.00 score]
- **Key Concerns:** [list if any]
- **Reasoning:** [explanation]

#### Design Concept
- **Product:** [product type]
- **Concept:** [description aligned with brand voice]
- **Target Audience:** [description]

#### Pricing Strategy
- **Recommended Price:** $[amount]
- **Minimum Viable Price:** $[amount]
- **Expected Margin:** [percentage]
- **Cost Breakdown:** [base cost, fees, profit]

#### Next Steps
[Actionable recommendations based on the analysis]
```

## Error Recovery

MCP servers implement circuit breaker patterns that automatically handle failures:

- **Circuit Breaker States:** Closed (normal) → Open (failing) → Half-Open (testing recovery)
- **Automatic Tier Fallback:** data-etsy automatically tries next tier on failure
- **Cache-First Strategy:** Reduces API failures by serving cached data when available

If tool invocations fail:
1. Note the error and which tier failed
2. Rely on automatic fallback to next tier
3. Include data source and confidence in final report
4. **Do not halt workflow** - proceed with best available data

## Development Commands

```bash
# Install dependencies
npm install

# No lint or tests configured currently
npm run lint   # echoes "no lint configured"
npm run test   # echoes "no tests configured"

# Test MCP servers manually
cd .claude/mcp-servers/logic-validator
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | node index.js

# Test validate_niche tool
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"validate_niche","arguments":{"niche":"pickleball","etsy_count":1500,"trend_score":0.65}}}' | node index.js

# Test data-etsy with debug mode
cd .claude/mcp-servers/data-etsy
DEBUG_MCP=1 node test.js

# Test trends API
cd .claude/mcp-servers/data-trends
node index.js
```

## Configuration Files

- **`.mcp.json`** - MCP server configuration with environment variable mapping
- **`plugin.json`** - Plugin metadata, skill definitions, token budgets, automation hooks
- **`.env`** - API keys (gitignored): `ETSY_API_KEY`, `ETSY_ACCESS_TOKEN`, `SERPER_API_KEY`, `PERPLEXITY_API_KEY`, `BRAVE_API_KEY`
- **`.claude/config/fallbacks.json`** - Fallback strategies for failed operations
- **`.claude/config/checkpoint-strategy.json`** - Checkpoint configuration

## Naming Conventions

From `NAMING_CONVENTIONS.md`:

- **Files/Directories:** lowercase-with-hyphens
- **Skills:** `{domain}-{action}` (e.g., `pod-research`)
- **MCP Tools:** snake_case verbs (`validate_niche`, `calculate_price`, `etsy_get_listing_count`)
- **Brand Voice Files:** `brand_voice_{brand}.md`
- **Data Files:** `validated_{entity}.json`
- **Environment Variables:** ALL_CAPS_SNAKE_CASE with service prefix
- **Python functions:** snake_case
- **JavaScript functions:** camelCase
- **Classes:** PascalCase

## Performance Targets

- **Niche Validation:** <30 seconds, 99% deterministic accuracy
- **Price Calculation:** <5 seconds, fully deterministic
- **Full Pipeline:** 8K-12K tokens (research → design → pricing → listing)
- **Research-Only:** 2K-3K tokens (fast validation)
- **Cache Hit Rate:** Target >80% for Etsy listing counts

## Token Budget Management

From `plugin.json`:

- **Total Context Window:** 200,000 tokens
- **Auto-compact:** Triggers at 180K tokens
- **Per-Skill Budgets:**
  - pod-research: 1.5K-2.5K
  - pod-design-review: 5K-8K
  - pod-pricing: 100-150
  - pod-listing-seo: 4K-6K
  - memory-manager: 0.5K-0.9K

## Data Persistence

- **History:** `.claude/memories/history.json` - All research runs with full context
- **Validated Niches:** `.claude/memories/validated_niches.json` - GO decisions only
- **Skipped Niches:** `.claude/data/skipped_niches.json` - SKIP decisions with reasoning
- **Brand Voice:** `.claude/memories/brand_voice_{brand}.md` - Style guides for each brand
- **Etsy Cache:** `.cache/etsy-listing-counts.json` - Cached listing counts with timestamps
- **Logs:** `.claude/data/logs/` - MCP call logs, API usage, errors
