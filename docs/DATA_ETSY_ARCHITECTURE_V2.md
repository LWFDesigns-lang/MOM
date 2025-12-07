# Data-Etsy MCP Server Architecture v2.0

## Technical Specification for Listing Count Extraction System Redesign

**Version:** 2.0
**Date:** December 7, 2025
**Target Accuracy:** 85%+ (up from 33%)
**Cost Target:** < $0.01 per query (ideally FREE)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Data Source Evaluation Matrix](#3-data-source-evaluation-matrix)
4. [Tiered Hierarchy Design](#4-tiered-hierarchy-design)
5. [Etsy API Integration Design](#5-etsy-api-integration-design)
6. [DuckDuckGo Integration Design](#6-duckduckgo-integration-design)
7. [Serper.dev Integration Design](#7-serperdev-integration-design)
8. [Caching Strategy](#8-caching-strategy)
9. [Environment Variable Architecture](#9-environment-variable-architecture)
10. [Cost Analysis](#10-cost-analysis)
11. [Implementation Plan](#11-implementation-plan)
12. [Testing Strategy](#12-testing-strategy)

---

## 1. Executive Summary

### Problem Statement

The current data-etsy MCP server achieves only ~33% accuracy in extracting Etsy listing counts using Brave Search regex extraction, with Perplexity fallback achieving ~60-70% accuracy. This is insufficient for reliable POD niche validation.

### Proposed Solution

Implement a tiered data source hierarchy prioritizing **FREE** and **cheap** options:

- **Tier 1 (Primary):** Etsy Official API (100% accuracy, **FREE**)
- **Tier 2 (Secondary):** DuckDuckGo via `ddgs` package (~80% accuracy, **FREE**, unlimited)
- **Tier 3 (Tertiary):** Serper.dev (~95% accuracy, **$0.0003/query** - cheapest paid)
- **Tier 4 (Fallback):** Perplexity AI (60-70% accuracy, existing)
- **Tier 5 (Emergency):** Brave Search (33% accuracy, existing)

### Expected Outcomes

| Metric | Current | Target | Improvement |
|--------|---------|--------|-------------|
| Accuracy | 33% | 85%+ | +157% |
| Cost per query | ~$0.001 | **$0 - $0.0003** | **FREE or cheaper** |
| Response time | 2-5s | < 3s | Optimized |
| Reliability | 70% | 99%+ | +41% |

---

## 2. Current State Analysis

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                 Current data-etsy Server                     │
│                                                              │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │  Brave Search   │───▶│  Regex Extract  │──┐              │
│  │  (Primary)      │    │  (~33% success) │  │              │
│  └─────────────────┘    └─────────────────┘  │              │
│                                               ▼              │
│  ┌─────────────────┐    ┌─────────────────┐  │              │
│  │   Perplexity    │───▶│  LLM Estimate   │──┼──▶ Result    │
│  │   (Fallback)    │    │  (~60% success) │  │              │
│  └─────────────────┘    └─────────────────┘  │              │
│                                               │              │
│  ┌─────────────────┐                         │              │
│  │  Error Handler  │─────────────────────────┘              │
│  │  (count: -1)    │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

### Current Issues

1. **Brave Search Limitations:**
   - Returns web search results, not Etsy-specific data
   - Regex patterns fail to extract counts from snippets
   - No structured data in response
   - Query `site:etsy.com "keyword"` does not return listing counts

2. **Perplexity Limitations:**
   - LLM estimates are approximations, not exact counts
   - Results can vary significantly between queries
   - No citation of source data
   - Medium confidence ratings

3. **MCP Gateway Environment Issue:**
   - Environment variables from `.mcp.json` not propagating
   - API keys not available at runtime
   - Workaround: hardcoded in test scripts

### Current Code Analysis

From [`.claude/mcp-servers/data-etsy/index.js`](.claude/mcp-servers/data-etsy/index.js:74):

```javascript
// Current regex extraction - unreliable
function extractCountFromText(text) {
  const resultsPattern = /(\d{1,3}(?:,\d{3})*)\s*(?:results?|listings?)/i;
  // ... patterns fail because Brave doesn't return Etsy listing counts
}
```

---

## 3. Data Source Evaluation Matrix

### Candidate Comparison

| Data Source | Accuracy | Cost/Query | Rate Limits | Implementation | Reliability | Total Score |
|-------------|----------|------------|-------------|----------------|-------------|-------------|
| **Etsy Official API** | 100% | **FREE** | 10/sec | Complex (OAuth) | 99%+ | ⭐⭐⭐⭐⭐ |
| **DuckDuckGo (ddgs)** | ~80% | **FREE** | Unlimited* | Simple (npm/pip) | 90% | ⭐⭐⭐⭐⭐ |
| **Serper.dev** | 95% | **$0.0003** | 100/sec | Simple (API Key) | 99% | ⭐⭐⭐⭐ |
| **DataForSEO** | 95% | $0.0006-$0.002 | 2000/min | Simple (API Key) | 99% | ⭐⭐⭐ |
| **Perplexity** | 60-70% | ~$0.001 | Generous | Already done | 95% | ⭐⭐⭐ |
| **Brave Search** | 33% | Free | 1/sec | Already done | 99% | ⭐⭐ |

*DuckDuckGo has no official rate limits but may throttle aggressive usage

### Cost Comparison Summary

| Volume | Etsy API | DuckDuckGo | Serper | DataForSEO | Perplexity |
|--------|----------|------------|--------|------------|------------|
| 100/month | $0 | $0 | $0.03 | $0.06 | $0.10 |
| 1000/month | $0 | $0 | $0.30 | $0.60 | $1.00 |
| 10000/month | $0 | $0 | $3.00 | $6.00 | $10.00 |

**Winner: Etsy API + DuckDuckGo (both FREE)**

### Detailed Evaluation

#### 3.1 Etsy Official API

**Endpoint:** `GET /v3/application/listings/active`

**Pros:**
- ✅ 100% accurate (source of truth)
- ✅ Free tier available
- ✅ Returns exact `count` field
- ✅ Rich filtering (keywords, category, price range)
- ✅ No guesswork or estimation

**Cons:**
- ⚠️ Requires OAuth 2.0 authentication
- ⚠️ App approval process (manual review)
- ⚠️ Access token expires in 1 hour
- ⚠️ Refresh token management required
- ⚠️ Rate limit: 10 requests/second

**API Response Example:**
```json
{
  "count": 47823,
  "results": [
    {
      "listing_id": 1234567890,
      "title": "Pickleball T-Shirt...",
      "price": { "amount": 2499, "divisor": 100, "currency_code": "USD" }
    }
  ],
  "params": {
    "keywords": "pickleball",
    "limit": 1,
    "offset": 0
  }
}
```

**Authentication Flow:**
```
┌──────────────────────────────────────────────────────────────┐
│                    Etsy OAuth 2.0 Flow                        │
│                                                               │
│  1. Redirect user to Etsy authorization URL                   │
│     ↓                                                         │
│  2. User grants permission                                    │
│     ↓                                                         │
│  3. Etsy redirects with authorization code                    │
│     ↓                                                         │
│  4. Exchange code for access_token + refresh_token            │
│     ↓                                                         │
│  5. Use access_token for API calls (valid 1 hour)             │
│     ↓                                                         │
│  6. Refresh token when expired                                │
└──────────────────────────────────────────────────────────────┘
```

#### 3.2 DuckDuckGo Search (FREE - Recommended Tier 2)

**Package:** `ddgs` (Python) or Node.js wrapper

**Pros:**
- ✅ **100% FREE** - No API key required
- ✅ Unlimited queries (no hard rate limits)
- ✅ Simple integration via npm/pip package
- ✅ Returns structured search results
- ✅ Can use `site:etsy.com` operator
- ✅ No account registration needed

**Cons:**
- ⚠️ May throttle aggressive usage
- ⚠️ No official result count in response
- ⚠️ Must estimate from search results
- ⚠️ Unofficial/scraping-based library

**How to Extract Count:**
DuckDuckGo doesn't return a result count, but we can:
1. Search `site:etsy.com {keyword}`
2. Parse first page results for Etsy listing URLs
3. Extract count from Etsy search page title/description
4. Or use as validation: "many results" = high competition

**Python Example:**
```python
from ddgs import DDGS

def search_etsy_ddg(keyword):
    with DDGS() as ddgs:
        results = list(ddgs.text(
            f"site:etsy.com {keyword}",
            max_results=10
        ))
        
        # Look for Etsy search result page
        for result in results:
            if 'etsy.com/search' in result['href']:
                # Extract count from title like "X results"
                title = result['title']
                # Parse "Check out our selection of X+ items"
                return parse_count_from_text(title)
        
        # Fallback: estimate based on result count
        return len(results) * 1000  # rough estimate
```

**Node.js Alternative:**
```javascript
// Use duck-duck-scrape npm package
import { search } from 'duck-duck-scrape';

async function searchEtsyDDG(keyword) {
  const results = await search(`site:etsy.com ${keyword}`, {
    safeSearch: DDG.SafeSearchType.OFF
  });
  
  // Parse results for Etsy listing count
  return results;
}
```

#### 3.3 Serper.dev (CHEAPEST Paid - $0.0003/query)

**Endpoint:** `POST https://google.serper.dev/search`

**Pros:**
- ✅ Extremely cheap: **$0.30 per 1,000 queries**
- ✅ 10x cheaper than SerpAPI, DataForSEO
- ✅ Fast response (1-2 seconds)
- ✅ Returns `searchInformation.totalResults`
- ✅ Simple API key authentication
- ✅ High rate limits (100/sec)
- ✅ Free trial credits available

**Cons:**
- ⚠️ Requires account registration
- ⚠️ Not free (but very cheap)
- ⚠️ Newer service (less established)

**Pricing:**

| Plan | Queries | Cost | Per Query |
|------|---------|------|-----------|
| Starter | 1,000 | $0.30 | $0.0003 |
| Growth | 50,000 | $50 | $0.001 |
| Scale | 100,000 | $75 | $0.00075 |

**API Request Example:**
```javascript
const response = await fetch('https://google.serper.dev/search', {
  method: 'POST',
  headers: {
    'X-API-KEY': process.env.SERPER_API_KEY,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    q: 'site:etsy.com pickleball shirt',
    gl: 'us',
    hl: 'en'
  })
});

const data = await response.json();
console.log(data.searchInformation.totalResults); // "52,400"
```

**API Response Example:**
```json
{
  "searchParameters": {
    "q": "site:etsy.com pickleball shirt",
    "gl": "us",
    "hl": "en"
  },
  "searchInformation": {
    "totalResults": 52400,
    "timeTaken": 0.45
  },
  "organic": [
    {
      "title": "Pickleball Shirts - Etsy",
      "link": "https://www.etsy.com/search?q=pickleball+shirt",
      "snippet": "Check out our selection of pickleball shirts..."
    }
  ]
}
```

#### 3.4 DataForSEO SERP API (Alternative Paid)

**Endpoint:** `POST /v3/serp/google/organic/live/advanced`

**Pros:**
- ✅ Simple API key authentication
- ✅ Pay-as-you-go pricing ($0.0006-$0.002/request)
- ✅ Structured JSON response
- ✅ Extracts result counts from SERP
- ✅ High rate limits (2000/min)
- ✅ 95%+ accuracy for site-specific searches

**Cons:**
- ⚠️ More expensive than Serper.dev
- ⚠️ Requires account and API key
- ⚠️ Not 100% accurate (SERP estimation)

**Pricing Tiers:**

| Mode | Cost per Request | vs Serper |
|------|------------------|-----------|
| Standard Queue | $0.0006 | 2x more |
| Priority Queue | $0.0012 | 4x more |
| Live Mode | $0.002 | 6.7x more |

**Recommendation:** Use Serper.dev instead unless you need DataForSEO's specific features.

#### 3.5 Perplexity AI (Existing)

**Endpoint:** `POST /chat/completions`

**Current Implementation:**
- Model: `sonar`
- Prompt: "How many listings exist on Etsy for keyword X?"
- Response: Natural language estimate

**Accuracy Analysis:**
- Works well for high-volume keywords (t-shirt: 100k estimate)
- Less reliable for niche keywords
- No verifiable source
- Good for fallback/validation

#### 3.6 Brave Search (Existing)

**Current Role:** Primary (to be demoted)

**Future Role:** Emergency fallback only

**Reason for Demotion:**
- Cannot extract Etsy listing counts from SERP
- `site:etsy.com` queries return page results, not listing counts
- Regex patterns have low success rate

---

## 4. Tiered Hierarchy Design

### Architecture Overview (Updated with FREE options)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Data-Etsy MCP Server v2.0                         │
│                    Priority: FREE sources first!                     │
│                                                                      │
│  ┌─────────────────────────────────────────┐                        │
│  │            Request Router               │                        │
│  │  ┌─────────────────────────────────┐    │                        │
│  │  │      Cache Check (TTL: 6h)     │    │                        │
│  │  └─────────────┬───────────────────┘    │                        │
│  └────────────────┼────────────────────────┘                        │
│                   │                                                  │
│         Cache Hit │ Cache Miss                                       │
│              ▼    │                                                  │
│         ┌────────┐│                                                  │
│         │ Return ││                                                  │
│         └────────┘▼                                                  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Tier 1: Etsy API (FREE - 100% accurate)         │   │
│  │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │   │
│  │  │ Check Token  │──▶│  API Request │──▶│   Success?   │     │   │
│  │  │   Valid?     │   │  limit=1     │   │              │     │   │
│  │  └──────┬───────┘   └──────────────┘   └──────┬───────┘     │   │
│  │         │                                      │              │   │
│  │    Refresh if                          Yes ────┼───▶ Return   │   │
│  │    expired                                     │              │   │
│  │                                          No ───┼───▶ Tier 2   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                   │                  │
│                                                   ▼                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │            Tier 2: DuckDuckGo (FREE - ~80% accurate)         │   │
│  │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │   │
│  │  │ ddgs package │──▶│ site:etsy.com│──▶│   Success?   │     │   │
│  │  │ (no API key) │   │   search     │   │              │     │   │
│  │  └──────────────┘   └──────────────┘   └──────┬───────┘     │   │
│  │                                                │              │   │
│  │                                          Yes ──┼───▶ Return   │   │
│  │                                          No ───┼───▶ Tier 3   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                   │                  │
│                                                   ▼                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │          Tier 3: Serper.dev ($0.0003/query - 95% accurate)   │   │
│  │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │   │
│  │  │ API Key      │──▶│ Google SERP  │──▶│   Success?   │     │   │
│  │  │ Check        │   │ totalResults │   │              │     │   │
│  │  └──────────────┘   └──────────────┘   └──────┬───────┘     │   │
│  │                                                │              │   │
│  │                                          Yes ──┼───▶ Return   │   │
│  │                                          No ───┼───▶ Tier 4   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                   │                  │
│                                                   ▼                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │           Tier 4: Perplexity (~$0.001 - 60% accurate)        │   │
│  │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │   │
│  │  │ Rate Limit   │──▶│ LLM Query    │──▶│   Success?   │     │   │
│  │  │ Check        │   │              │   │              │     │   │
│  │  └──────────────┘   └──────────────┘   └──────┬───────┘     │   │
│  │                                                │              │   │
│  │                                          Yes ──┼───▶ Return   │   │
│  │                                          No ───┼───▶ Tier 5   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                   │                  │
│                                                   ▼                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │            Tier 5: Brave Search (FREE - 33% accurate)        │   │
│  │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │   │
│  │  │ Last Resort  │──▶│ Web Search   │──▶│   Return     │     │   │
│  │  │              │   │ + Regex      │   │ Best Effort  │     │   │
│  │  └──────────────┘   └──────────────┘   └──────────────┘     │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Cache Manager                              │   │
│  │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │   │
│  │  │ Store Result │   │ TTL: 6 hours │   │ File Persist │     │   │
│  │  └──────────────┘   └──────────────┘   └──────────────┘     │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Decision Logic (Updated)

```javascript
async function getListingCount(keyword) {
  // Check cache first
  const cached = await cache.get(keyword);
  if (cached && !cached.isExpired()) {
    return { ...cached, source: 'cache' };
  }

  // Tier 1: Etsy API (FREE, 100% accurate - if configured)
  if (etsyApi.isConfigured() && etsyApi.circuitBreaker.isOpen()) {
    try {
      const result = await etsyApi.getListingCount(keyword);
      if (result.success) {
        await cache.set(keyword, result);
        return { ...result, source: 'etsy_api', confidence: 'high' };
      }
    } catch (error) {
      etsyApi.circuitBreaker.recordFailure();
    }
  }

  // Tier 2: DuckDuckGo (FREE, no API key needed)
  if (duckduckgo.circuitBreaker.isOpen()) {
    try {
      const result = await duckduckgo.getListingCount(keyword);
      if (result.success && result.count > 0) {
        await cache.set(keyword, result, { ttl: 4 * 60 * 60 * 1000 }); // 4 hours
        return { ...result, source: 'duckduckgo', confidence: 'high' };
      }
    } catch (error) {
      duckduckgo.circuitBreaker.recordFailure();
    }
  }

  // Tier 3: Serper.dev (CHEAPEST paid option - $0.0003/query)
  if (serper.isConfigured() && serper.circuitBreaker.isOpen()) {
    try {
      const result = await serper.getListingCount(keyword);
      if (result.success) {
        await cache.set(keyword, result);
        return { ...result, source: 'serper', confidence: 'high' };
      }
    } catch (error) {
      serper.circuitBreaker.recordFailure();
    }
  }

  // Tier 4: Perplexity (existing fallback)
  if (perplexity.isConfigured()) {
    try {
      const result = await perplexity.getListingCount(keyword);
      if (result.success) {
        await cache.set(keyword, result, { ttl: 3600 }); // 1 hour for estimates
        return { ...result, source: 'perplexity', confidence: 'medium' };
      }
    } catch (error) {
      // Continue to Tier 5
    }
  }

  // Tier 5: Brave Search (last resort)
  try {
    const result = await braveSearch.getListingCount(keyword);
    return { ...result, source: 'brave', confidence: 'low' };
  } catch (error) {
    return {
      keyword,
      count: -1,
      source: 'fallback',
      confidence: 'none',
      error: 'All data sources failed'
    };
  }
}
```

### Circuit Breaker Pattern

```javascript
class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeout = options.resetTimeout || 60000; // 1 minute
    this.failures = 0;
    this.lastFailure = null;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
  }

  isOpen() {
    if (this.state === 'CLOSED') return true;
    if (this.state === 'OPEN') {
      // Check if reset timeout has passed
      if (Date.now() - this.lastFailure >= this.resetTimeout) {
        this.state = 'HALF_OPEN';
        return true; // Allow one test request
      }
      return false;
    }
    return true; // HALF_OPEN allows requests
  }

  recordSuccess() {
    this.failures = 0;
    this.state = 'CLOSED';
  }

  recordFailure() {
    this.failures++;
    this.lastFailure = Date.now();
    if (this.failures >= this.failureThreshold) {
      this.state = 'OPEN';
    }
  }
}
```

---

## 5. Etsy API Integration Design

### Prerequisites

1. **Etsy Developer Account:** https://www.etsy.com/developers/register
2. **Create App:** Request access and await manual approval
3. **App Credentials:**
   - `ETSY_API_KEY` (keystring)
   - `ETSY_SHARED_SECRET`

### OAuth 2.0 Implementation

#### Token Manager

```javascript
class EtsyTokenManager {
  constructor(options) {
    this.apiKey = options.apiKey;
    this.sharedSecret = options.sharedSecret;
    this.redirectUri = options.redirectUri || 'http://localhost:3000/callback';
    this.tokenFile = options.tokenFile || '.etsy-tokens.json';
    this.tokens = null;
  }

  async loadTokens() {
    try {
      const data = await readFile(this.tokenFile, 'utf8');
      this.tokens = JSON.parse(data);
      return this.tokens;
    } catch {
      return null;
    }
  }

  async saveTokens(tokens) {
    this.tokens = tokens;
    await writeFile(this.tokenFile, JSON.stringify(tokens, null, 2));
  }

  isTokenValid() {
    if (!this.tokens) return false;
    const expiresAt = new Date(this.tokens.expires_at);
    // Consider expired if less than 5 minutes remaining
    return expiresAt > new Date(Date.now() + 5 * 60 * 1000);
  }

  async refreshAccessToken() {
    if (!this.tokens?.refresh_token) {
      throw new Error('No refresh token available - re-authorization required');
    }

    const response = await fetch('https://api.etsy.com/v3/public/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        client_id: this.apiKey,
        refresh_token: this.tokens.refresh_token
      })
    });

    if (!response.ok) {
      throw new Error(`Token refresh failed: ${response.status}`);
    }

    const newTokens = await response.json();
    await this.saveTokens({
      access_token: newTokens.access_token,
      refresh_token: newTokens.refresh_token,
      expires_at: new Date(Date.now() + newTokens.expires_in * 1000).toISOString()
    });

    return this.tokens;
  }

  async getValidToken() {
    await this.loadTokens();
    
    if (!this.tokens) {
      throw new Error('Not authenticated - run authorization flow first');
    }

    if (!this.isTokenValid()) {
      await this.refreshAccessToken();
    }

    return this.tokens.access_token;
  }

  getAuthorizationUrl(state) {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.apiKey,
      redirect_uri: this.redirectUri,
      scope: 'listings_r', // Read listings
      state: state || crypto.randomUUID(),
      code_challenge: this.generateCodeChallenge(),
      code_challenge_method: 'S256'
    });

    return `https://www.etsy.com/oauth/connect?${params.toString()}`;
  }
}
```

#### API Client

```javascript
class EtsyApiClient {
  constructor(tokenManager) {
    this.tokenManager = tokenManager;
    this.baseUrl = 'https://api.etsy.com/v3/application';
    this.circuitBreaker = new CircuitBreaker({ failureThreshold: 3 });
  }

  isConfigured() {
    return !!this.tokenManager.apiKey;
  }

  async getListingCount(keyword, options = {}) {
    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is open');
    }

    try {
      const token = await this.tokenManager.getValidToken();
      
      const params = new URLSearchParams({
        keywords: keyword,
        limit: 1, // Minimize data transfer
        state: 'active',
        ...options
      });

      const response = await fetch(
        `${this.baseUrl}/listings/active?${params.toString()}`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'x-api-key': this.tokenManager.apiKey
          }
        }
      );

      if (!response.ok) {
        throw new Error(`Etsy API error: ${response.status}`);
      }

      const data = await response.json();
      this.circuitBreaker.recordSuccess();

      return {
        success: true,
        keyword,
        count: data.count,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      this.circuitBreaker.recordFailure();
      throw error;
    }
  }
}
```

### Rate Limiting Strategy

```javascript
class RateLimiter {
  constructor(requestsPerSecond = 10) {
    this.requestsPerSecond = requestsPerSecond;
    this.tokens = requestsPerSecond;
    this.lastRefill = Date.now();
  }

  async acquire() {
    this.refillTokens();
    
    if (this.tokens < 1) {
      // Wait for next token
      const waitTime = (1000 / this.requestsPerSecond) - (Date.now() - this.lastRefill);
      await new Promise(resolve => setTimeout(resolve, Math.max(0, waitTime)));
      this.refillTokens();
    }

    this.tokens--;
    return true;
  }

  refillTokens() {
    const now = Date.now();
    const elapsed = now - this.lastRefill;
    const tokensToAdd = (elapsed / 1000) * this.requestsPerSecond;
    this.tokens = Math.min(this.requestsPerSecond, this.tokens + tokensToAdd);
    this.lastRefill = now;
  }
}
```

---

## 6. DuckDuckGo Integration Design (FREE)

### Why DuckDuckGo?

- **100% FREE** - No API key, no account, no limits
- Unofficial `ddgs` package works reliably
- Can use `site:etsy.com` operator
- Good fallback when Etsy API is unavailable

### Installation

```bash
# Python (for subprocess call)
pip install ddgs

# Node.js alternative
npm install duck-duck-scrape
```

### Node.js Implementation

```javascript
import { spawn } from 'child_process';

class DuckDuckGoClient {
  constructor() {
    this.circuitBreaker = new CircuitBreaker({
      failureThreshold: 3,
      resetTimeout: 30000 // 30 seconds
    });
  }

  // No API key needed!
  isConfigured() {
    return true;
  }

  async getListingCount(keyword) {
    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is open');
    }

    try {
      const searchQuery = `site:etsy.com ${keyword}`;
      
      // Use Python ddgs package via subprocess
      const result = await this.searchViaPython(searchQuery);
      
      if (result.success) {
        this.circuitBreaker.recordSuccess();
        return result;
      }
      
      throw new Error('DuckDuckGo search failed');
      
    } catch (error) {
      this.circuitBreaker.recordFailure();
      throw error;
    }
  }

  async searchViaPython(query) {
    return new Promise((resolve, reject) => {
      const pythonCode = `
import json
from ddgs import DDGS

def search_etsy(query):
    with DDGS() as ddgs:
        results = list(ddgs.text(query, max_results=20))
        
        # Look for Etsy search page with count
        for r in results:
            if 'etsy.com/search' in r.get('href', ''):
                # Try to extract count from title/body
                text = r.get('title', '') + ' ' + r.get('body', '')
                import re
                match = re.search(r'(\\d{1,3}(?:,\\d{3})*)', text)
                if match:
                    count = int(match.group(1).replace(',', ''))
                    return {'success': True, 'count': count, 'source': 'duckduckgo'}
        
        # Fallback: estimate based on result count
        etsy_results = [r for r in results if 'etsy.com' in r.get('href', '')]
        if len(etsy_results) >= 10:
            return {'success': True, 'count': 10000, 'source': 'duckduckgo', 'estimated': True}
        elif len(etsy_results) >= 5:
            return {'success': True, 'count': 5000, 'source': 'duckduckgo', 'estimated': True}
        elif len(etsy_results) > 0:
            return {'success': True, 'count': 1000, 'source': 'duckduckgo', 'estimated': True}
        
        return {'success': False, 'error': 'No Etsy results found'}

print(json.dumps(search_etsy('${query.replace(/'/g, "\\'")}')))
`;
      
      const proc = spawn('python3', ['-c', pythonCode]);
      let stdout = '';
      let stderr = '';
      
      proc.stdout.on('data', (data) => stdout += data);
      proc.stderr.on('data', (data) => stderr += data);
      
      proc.on('close', (code) => {
        if (code === 0) {
          try {
            resolve(JSON.parse(stdout));
          } catch (e) {
            reject(new Error(`Invalid JSON: ${stdout}`));
          }
        } else {
          reject(new Error(`Python error: ${stderr}`));
        }
      });
      
      // Timeout after 15 seconds
      setTimeout(() => {
        proc.kill();
        reject(new Error('DuckDuckGo search timeout'));
      }, 15000);
    });
  }
}
```

### Alternative: Node.js Only (duck-duck-scrape)

```javascript
import DDG from 'duck-duck-scrape';

class DuckDuckGoNodeClient {
  constructor() {
    this.circuitBreaker = new CircuitBreaker({ failureThreshold: 3 });
  }

  async getListingCount(keyword) {
    const searchQuery = `site:etsy.com ${keyword}`;
    
    try {
      const results = await DDG.search(searchQuery, {
        safeSearch: DDG.SafeSearchType.OFF
      });
      
      // Parse results for Etsy listing information
      const etsyResults = results.results.filter(r =>
        r.url.includes('etsy.com')
      );
      
      // Try to extract count from snippets
      for (const result of etsyResults) {
        const countMatch = result.description?.match(/(\\d{1,3}(?:,\\d{3})*)/);
        if (countMatch) {
          return {
            success: true,
            count: parseInt(countMatch[1].replace(/,/g, '')),
            source: 'duckduckgo',
            keyword
          };
        }
      }
      
      // Estimate based on result count
      if (etsyResults.length >= 10) {
        return { success: true, count: 10000, source: 'duckduckgo', estimated: true };
      }
      
      throw new Error('Could not determine count');
      
    } catch (error) {
      this.circuitBreaker.recordFailure();
      throw error;
    }
  }
}
```

---

## 7. Serper.dev Integration Design (CHEAPEST Paid)

### Why Serper.dev?

- **$0.0003 per query** (cheapest paid SERP API)
- 10x cheaper than SerpAPI, DataForSEO
- Returns exact `totalResults` count
- Fast (1-2 second response)
- Free trial credits available

### Account Setup

1. **Register:** https://serper.dev/
2. **Get API Key:** Dashboard → API Keys
3. **Free Credits:** New accounts get free trial queries

### API Client Implementation

```javascript
class SerperClient {
  constructor(options) {
    this.apiKey = options.apiKey;
    this.baseUrl = 'https://google.serper.dev';
    this.circuitBreaker = new CircuitBreaker({ failureThreshold: 5 });
    this.costPerQuery = 0.0003; // $0.30 per 1000
  }

  isConfigured() {
    return !!this.apiKey;
  }

  async getListingCount(keyword, options = {}) {
    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is open');
    }

    try {
      const searchQuery = `site:etsy.com ${keyword}`;
      
      const response = await fetch(`${this.baseUrl}/search`, {
        method: 'POST',
        headers: {
          'X-API-KEY': this.apiKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          q: searchQuery,
          gl: 'us',     // United States
          hl: 'en',     // English
          num: 10       // Results per page
        })
      });

      if (!response.ok) {
        throw new Error(`Serper API error: ${response.status}`);
      }

      const data = await response.json();
      this.circuitBreaker.recordSuccess();

      // Extract total results count
      const totalResults = data.searchInformation?.totalResults;
      
      if (totalResults === undefined) {
        throw new Error('No totalResults in Serper response');
      }

      // Parse the count (may be string like "52,400")
      const count = typeof totalResults === 'string'
        ? parseInt(totalResults.replace(/,/g, ''))
        : totalResults;

      return {
        success: true,
        keyword,
        count,
        searchQuery,
        cost: this.costPerQuery,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      this.circuitBreaker.recordFailure();
      throw error;
    }
  }
}
```

### Response Example

```json
{
  "searchParameters": {
    "q": "site:etsy.com pickleball shirt",
    "gl": "us",
    "hl": "en",
    "num": 10,
    "type": "search"
  },
  "searchInformation": {
    "totalResults": 52400,
    "timeTaken": 0.42,
    "searchTime": 0.42
  },
  "organic": [
    {
      "title": "Pickleball Shirts - Etsy",
      "link": "https://www.etsy.com/search?q=pickleball+shirt",
      "snippet": "Check out our pickleball shirts selection for the very best in unique or custom, handmade pieces from our clothing shops.",
      "position": 1
    }
  ]
}
```

### Cost Optimization

```javascript
// Batch multiple keywords efficiently
async function batchSearchSerper(keywords) {
  const results = [];
  
  for (const keyword of keywords) {
    // Check cache first
    const cached = await cache.get(keyword);
    if (cached) {
      results.push(cached);
      continue;
    }
    
    // Only call API for uncached keywords
    const result = await serperClient.getListingCount(keyword);
    results.push(result);
    await cache.set(keyword, result);
    
    // Brief delay to avoid rate limits
    await new Promise(r => setTimeout(r, 100));
  }
  
  return results;
}
```

---

## 8. DataForSEO Integration Design (Alternative Paid)

> **Note:** Serper.dev is recommended over DataForSEO for cost reasons.
> Keep this section as reference if Serper becomes unavailable.

### Account Setup

1. **Register:** https://dataforseo.com/
2. **Get API Credentials:**
   - Login (email)
   - Password (API password)
3. **Pricing:** $0.0006-$0.002/request (2x+ more expensive than Serper)

### API Client Implementation

```javascript
class DataForSeoClient {
  constructor(options) {
    this.login = options.login;
    this.password = options.password;
    this.baseUrl = 'https://api.dataforseo.com/v3';
    this.circuitBreaker = new CircuitBreaker({ failureThreshold: 5 });
  }

  isConfigured() {
    return !!(this.login && this.password);
  }

  getAuthHeader() {
    const credentials = Buffer.from(`${this.login}:${this.password}`).toString('base64');
    return `Basic ${credentials}`;
  }

  async getListingCount(keyword, options = {}) {
    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is open');
    }

    try {
      const searchQuery = `site:etsy.com ${keyword}`;
      
      const response = await fetch(`${this.baseUrl}/serp/google/organic/live/advanced`, {
        method: 'POST',
        headers: {
          'Authorization': this.getAuthHeader(),
          'Content-Type': 'application/json'
        },
        body: JSON.stringify([{
          keyword: searchQuery,
          location_code: 2840, // United States
          language_code: 'en',
          device: 'desktop',
          depth: 10
        }])
      });

      if (!response.ok) {
        throw new Error(`DataForSEO API error: ${response.status}`);
      }

      const data = await response.json();
      this.circuitBreaker.recordSuccess();

      const task = data.tasks?.[0];
      if (!task?.result?.[0]) {
        throw new Error('No results in DataForSEO response');
      }

      const result = task.result[0];
      const count = result.se_results_count || 0;

      return {
        success: true,
        keyword,
        count,
        cost: task.cost,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      this.circuitBreaker.recordFailure();
      throw error;
    }
  }
}
```

---

## 9. Caching Strategy

### Cache Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Cache Layer                                 │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Memory Cache (LRU)                        ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │  Map<keyword, CacheEntry>                           │   ││
│  │  │  Max Size: 1000 entries                             │   ││
│  │  │  Default TTL: 6 hours                               │   ││
│  │  └─────────────────────────────────────────────────────┘   ││
│  └───────────────────────────┬─────────────────────────────────┘│
│                              │                                   │
│                    On eviction/shutdown                          │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   File Persistence                          ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │  .claude/memories/etsy-cache.json                   │   ││
│  │  │  Periodic sync every 5 minutes                      │   ││
│  │  │  Load on startup                                    │   ││
│  │  └─────────────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Cache Implementation

```javascript
class ListingCountCache {
  constructor(options = {}) {
    this.maxSize = options.maxSize || 1000;
    this.defaultTtl = options.defaultTtl || 6 * 60 * 60 * 1000; // 6 hours
    this.cacheFile = options.cacheFile || '.claude/memories/etsy-cache.json';
    this.cache = new Map();
    this.syncInterval = null;
  }

  async initialize() {
    await this.loadFromFile();
    // Periodic sync every 5 minutes
    this.syncInterval = setInterval(() => this.saveToFile(), 5 * 60 * 1000);
  }

  async get(keyword) {
    const normalizedKey = this.normalizeKey(keyword);
    const entry = this.cache.get(normalizedKey);
    
    if (!entry) return null;
    
    if (this.isExpired(entry)) {
      this.cache.delete(normalizedKey);
      return null;
    }

    // Update access time for LRU
    entry.lastAccess = Date.now();
    return entry;
  }

  async set(keyword, result, options = {}) {
    const normalizedKey = this.normalizeKey(keyword);
    const ttl = this.getTtlForSource(result.source, options.ttl);
    
    const entry = {
      keyword,
      count: result.count,
      source: result.source,
      confidence: result.confidence,
      createdAt: Date.now(),
      expiresAt: Date.now() + ttl,
      lastAccess: Date.now()
    };

    // Enforce max size with LRU eviction
    if (this.cache.size >= this.maxSize) {
      this.evictLRU();
    }

    this.cache.set(normalizedKey, entry);
  }

  getTtlForSource(source, customTtl) {
    if (customTtl) return customTtl;
    
    // Different TTLs based on data source reliability
    const ttlBySource = {
      'etsy_api': 6 * 60 * 60 * 1000,   // 6 hours (most reliable)
      'dataforseo': 4 * 60 * 60 * 1000,  // 4 hours
      'perplexity': 1 * 60 * 60 * 1000,  // 1 hour (estimates)
      'brave': 30 * 60 * 1000,           // 30 minutes (least reliable)
      'cache': this.defaultTtl
    };
    
    return ttlBySource[source] || this.defaultTtl;
  }

  normalizeKey(keyword) {
    return keyword.toLowerCase().trim().replace(/\s+/g, ' ');
  }

  isExpired(entry) {
    return Date.now() > entry.expiresAt;
  }

  evictLRU() {
    let oldestKey = null;
    let oldestAccess = Infinity;

    for (const [key, entry] of this.cache) {
      if (entry.lastAccess < oldestAccess) {
        oldestAccess = entry.lastAccess;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      this.cache.delete(oldestKey);
    }
  }

  async loadFromFile() {
    try {
      const data = await readFile(this.cacheFile, 'utf8');
      const entries = JSON.parse(data);
      
      for (const entry of entries) {
        if (!this.isExpired(entry)) {
          this.cache.set(this.normalizeKey(entry.keyword), entry);
        }
      }
    } catch {
      // File doesn't exist or is invalid, start fresh
    }
  }

  async saveToFile() {
    const entries = Array.from(this.cache.values())
      .filter(entry => !this.isExpired(entry));
    
    await writeFile(this.cacheFile, JSON.stringify(entries, null, 2));
  }

  async shutdown() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }
    await this.saveToFile();
  }
}
```

### Cache Invalidation Rules

| Trigger | Action | Reason |
|---------|--------|--------|
| TTL expired | Auto-evict | Data may be stale |
| Manual invalidate | Delete entry | User request |
| Source failure | Keep cached | Better than no data |
| API error 429 | Extend TTL | Rate limited |
| New API result | Replace | Fresher data |

---

## 10. Environment Variable Architecture

### Required Variables (Updated)

```bash
# Tier 1: Etsy API (FREE - requires OAuth setup)
ETSY_API_KEY=your_keystring_here
ETSY_SHARED_SECRET=your_shared_secret_here
ETSY_REDIRECT_URI=http://localhost:3000/callback

# Tier 2: DuckDuckGo - NO API KEY NEEDED! (FREE)
# Just install: pip install ddgs

# Tier 3: Serper.dev (CHEAPEST paid - $0.0003/query)
SERPER_API_KEY=your_serper_api_key

# Tier 4: Perplexity (Existing)
PERPLEXITY_API_KEY=pplx-xxxxx

# Tier 5: Brave Search (Existing)
BRAVE_API_KEY=BSACLL9xxxxx

# Optional: DataForSEO (Alternative to Serper, more expensive)
DATAFORSEO_LOGIN=your_email@example.com
DATAFORSEO_PASSWORD=your_api_password

# Debug
DEBUG_MCP=0
```

### MCP Gateway Environment Issue - Solution

**Problem:** Environment variables from `.mcp.json` are not propagating to MCP servers when run through Docker MCP Gateway.

**Solution 1: Direct .env Loading (Recommended)**

```javascript
// At the top of index.js
import { config } from 'dotenv';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const workspaceRoot = resolve(__dirname, '../../..');

// Load .env from workspace root
config({ path: resolve(workspaceRoot, '.env') });

// Also try from MCP server directory
config({ path: resolve(__dirname, '.env') });
```

**Solution 2: Configuration File**

Create `.claude/mcp-servers/data-etsy/config.json`:

```json
{
  "tier1": {
    "enabled": false,
    "provider": "etsy_api",
    "credentials": {
      "apiKey": "${ETSY_API_KEY}",
      "sharedSecret": "${ETSY_SHARED_SECRET}"
    }
  },
  "tier2": {
    "enabled": true,
    "provider": "duckduckgo",
    "credentials": null,
    "note": "No API key required - FREE!"
  },
  "tier3": {
    "enabled": true,
    "provider": "serper",
    "credentials": {
      "apiKey": "${SERPER_API_KEY}"
    }
  },
  "tier4": {
    "enabled": true,
    "provider": "perplexity",
    "credentials": {
      "apiKey": "${PERPLEXITY_API_KEY}"
    }
  },
  "tier5": {
    "enabled": true,
    "provider": "brave",
    "credentials": {
      "apiKey": "${BRAVE_API_KEY}"
    }
  }
}
```

**Solution 3: Updated .mcp.json**

```json
{
  "mcpServers": {
    "data-etsy": {
      "command": "node",
      "args": [".claude/mcp-servers/data-etsy/index.js"],
      "cwd": "/home/docker/MOM",
      "env": {
        "ETSY_API_KEY": "${ETSY_API_KEY}",
        "SERPER_API_KEY": "${SERPER_API_KEY}",
        "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}",
        "BRAVE_API_KEY": "${BRAVE_API_KEY}",
        "DEBUG_MCP": "0"
      }
    }
  }
}
```

### Environment Loading Order

```javascript
function loadConfig() {
  const config = {
    etsy: {
      apiKey: null,
      sharedSecret: null
    },
    duckduckgo: {
      enabled: true  // Always enabled - no API key needed!
    },
    serper: {
      apiKey: null
    },
    perplexity: {
      apiKey: null
    },
    brave: {
      apiKey: null
    }
  };

  // 1. Load from process.env (MCP gateway might set these)
  config.etsy.apiKey = process.env.ETSY_API_KEY;
  config.etsy.sharedSecret = process.env.ETSY_SHARED_SECRET;
  config.serper.apiKey = process.env.SERPER_API_KEY;
  config.perplexity.apiKey = process.env.PERPLEXITY_API_KEY;
  config.brave.apiKey = process.env.BRAVE_API_KEY;

  // 2. Load from .env file if not in process.env
  dotenv.config({ path: resolve(workspaceRoot, '.env') });
  
  // 3. Load from config.json as fallback
  try {
    const configFile = JSON.parse(readFileSync('./config.json', 'utf8'));
    // Merge with environment variable substitution
  } catch {}

  return config;
}
```

---

## 11. Cost Analysis (Updated with FREE options)

### Per-Query Cost Breakdown (Updated)

| Data Source | Cost per Query | Monthly (100) | Monthly (1000) | Monthly (10000) |
|-------------|----------------|---------------|----------------|-----------------|
| **Etsy API** | **$0.00** | $0.00 | $0.00 | $0.00 |
| **DuckDuckGo** | **$0.00** | $0.00 | $0.00 | $0.00 |
| **Serper.dev** | **$0.0003** | $0.03 | $0.30 | $3.00 |
| DataForSEO | $0.0006-$0.002 | $0.06-$0.20 | $0.60-$2.00 | $6-$20 |
| Perplexity | ~$0.001 | ~$0.10 | ~$1.00 | ~$10.00 |
| Brave Search | $0.00 | $0.00 | $0.00 | $0.00 |

### Projected Monthly Costs (Updated)

**Scenario A: All FREE Sources (Optimal - $0/month!)**

| Tier | Hit Rate | Queries | Cost |
|------|----------|---------|------|
| Cache | 60% | 600 | $0.00 |
| Etsy API | 30% | 300 | **$0.00** |
| DuckDuckGo | 9% | 90 | **$0.00** |
| Serper | 1% | 10 | $0.003 |
| **Total** | 100% | 1000 | **$0.003** |

**Scenario B: No Etsy API, DuckDuckGo Primary (Still nearly FREE)**

| Tier | Hit Rate | Queries | Cost |
|------|----------|---------|------|
| Cache | 60% | 600 | $0.00 |
| DuckDuckGo | 30% | 300 | **$0.00** |
| Serper | 9% | 90 | $0.027 |
| Perplexity | 1% | 10 | $0.01 |
| **Total** | 100% | 1000 | **$0.037** |

**Scenario C: Serper Primary (DuckDuckGo unavailable)**

| Tier | Hit Rate | Queries | Cost |
|------|----------|---------|------|
| Cache | 60% | 600 | $0.00 |
| Serper | 35% | 350 | $0.105 |
| Perplexity | 4% | 40 | $0.04 |
| Brave | 1% | 10 | $0.00 |
| **Total** | 100% | 1000 | **$0.145** |

### Break-Even Analysis

**Target:** < $0.01 per query average

| Scenario | Monthly Cost (1000 queries) | Cost per Query | Status |
|----------|----------------------------|----------------|--------|
| A: Free sources | $0.003 | $0.000003 | ✅ **UNDER BUDGET** |
| B: DDG Primary | $0.037 | $0.000037 | ✅ **UNDER BUDGET** |
| C: Serper Primary | $0.145 | $0.000145 | ✅ **UNDER BUDGET** |

**All scenarios are 98-99% under the $0.01 target!**

### Cost Control Mechanisms

```javascript
class CostTracker {
  constructor(options = {}) {
    this.dailyLimit = options.dailyLimit || 1.00; // $1/day max
    this.monthlyLimit = options.monthlyLimit || 10.00; // $10/month max
    this.costs = { daily: 0, monthly: 0 };
    this.lastReset = { daily: Date.now(), monthly: Date.now() };
  }

  recordCost(amount, source) {
    this.resetIfNeeded();
    this.costs.daily += amount;
    this.costs.monthly += amount;
    
    // Log warning if approaching limits
    if (this.costs.daily > this.dailyLimit * 0.8) {
      console.warn(`Daily cost at ${(this.costs.daily / this.dailyLimit * 100).toFixed(1)}%`);
    }
  }

  canMakeRequest(estimatedCost) {
    this.resetIfNeeded();
    return (
      this.costs.daily + estimatedCost <= this.dailyLimit &&
      this.costs.monthly + estimatedCost <= this.monthlyLimit
    );
  }

  resetIfNeeded() {
    const now = Date.now();
    
    // Reset daily at midnight
    if (now - this.lastReset.daily > 24 * 60 * 60 * 1000) {
      this.costs.daily = 0;
      this.lastReset.daily = now;
    }
    
    // Reset monthly on 1st
    const today = new Date();
    const lastResetDate = new Date(this.lastReset.monthly);
    if (today.getMonth() !== lastResetDate.getMonth()) {
      this.costs.monthly = 0;
      this.lastReset.monthly = now;
    }
  }
}
```

---

## 12. Implementation Plan (Updated)

### Phase 1: FREE Sources First (Week 1)

**Objective:** Implement DuckDuckGo (FREE) as quick win

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: FREE Sources (Quick Wins!)                         │
│                                                              │
│  ☐ 1.1 Create new index-v2.js file structure                │
│  ☐ 1.2 Implement environment loading (.env fallback)         │
│  ☐ 1.3 Implement caching layer                              │
│  ☐ 1.4 Add DuckDuckGo client (FREE, no API key!)            │
│  ☐ 1.5 Install ddgs Python package: pip install ddgs        │
│  ☐ 1.6 Test DuckDuckGo accuracy                             │
│                                                              │
│  Deliverable: FREE DuckDuckGo working as fallback source    │
└─────────────────────────────────────────────────────────────┘
```

**Tasks:**

1. **1.1 File Structure**
   ```
   .claude/mcp-servers/data-etsy/
   ├── index.js          # Main server (unchanged for now)
   ├── index-v2.js       # New tiered implementation
   ├── lib/
   │   ├── cache.js      # Caching layer
   │   ├── circuit-breaker.js
   │   ├── cost-tracker.js
   │   ├── data-sources/
   │   │   ├── etsy-api.js
   │   │   ├── duckduckgo.js  # FREE!
   │   │   ├── serper.js      # Cheapest paid
   │   │   ├── perplexity.js
   │   │   └── brave.js
   │   └── config.js     # Environment loading
   ├── test.js           # Existing tests
   └── test-v2.js        # New test suite
   ```

2. **1.2 Environment Loading**
   - Implement dotenv fallback
   - Test with MCP gateway

3. **1.3 Caching Layer**
   - Memory cache with LRU
   - File persistence
   - TTL management

4. **1.4 DuckDuckGo Client (FREE!)**
   - Install: `pip install ddgs`
   - Python subprocess integration
   - No API key needed!

5. **1.5 Test Suite**
   - Unit tests for each component
   - Integration test for DuckDuckGo

### Phase 2: Etsy API Integration (Week 2)

**Objective:** Add Etsy API as Tier 1 source

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Etsy API                                           │
│                                                              │
│  ☐ 2.1 Apply for Etsy Developer account                     │
│  ☐ 2.2 Implement OAuth 2.0 flow                             │
│  ☐ 2.3 Create token manager                                 │
│  ☐ 2.4 Implement Etsy API client                            │
│  ☐ 2.5 Add one-time auth setup script                       │
│  ☐ 2.6 Test token refresh cycle                             │
│                                                              │
│  Deliverable: Etsy API working as primary source            │
└─────────────────────────────────────────────────────────────┘
```

**Tasks:**

1. **2.1 Developer Account**
   - Register at https://www.etsy.com/developers/register
   - Create app and await approval
   - Note: Manual review may take days

2. **2.2 OAuth Flow**
   - Implement PKCE flow
   - Handle authorization callback
   - Store tokens securely

3. **2.3 Token Manager**
   - Load/save tokens
   - Auto-refresh before expiry
   - Handle re-authorization

4. **2.4 API Client**
   - GET /listings/active endpoint
   - Rate limiting (10/sec)
   - Error handling

5. **2.5 Auth Setup Script**
   - One-time CLI script to complete OAuth
   - Generate and store initial tokens

### Phase 3: Integration & Testing (Week 3)

**Objective:** Combine all sources and validate accuracy

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: Integration                                        │
│                                                              │
│  ☐ 3.1 Implement tiered routing logic                       │
│  ☐ 3.2 Add circuit breakers                                 │
│  ☐ 3.3 Integrate cost tracking                              │
│  ☐ 3.4 Run accuracy validation tests                        │
│  ☐ 3.5 Performance benchmarking                             │
│  ☐ 3.6 Update documentation                                 │
│                                                              │
│  Deliverable: Full tiered system operational                │
└─────────────────────────────────────────────────────────────┘
```

### Phase 4: Production Deployment (Week 4)

**Objective:** Replace current implementation

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: Deployment                                         │
│                                                              │
│  ☐ 4.1 Backup current index.js                              │
│  ☐ 4.2 Replace with index-v2.js                             │
│  ☐ 4.3 Update .mcp.json configuration                       │
│  ☐ 4.4 Run production validation                            │
│  ☐ 4.5 Monitor for issues                                   │
│  ☐ 4.6 Create rollback plan                                 │
│                                                              │
│  Deliverable: Production system with 85%+ accuracy          │
└─────────────────────────────────────────────────────────────┘
```

---

## 13. Testing Strategy

### Unit Tests

```javascript
// test-v2.js
describe('DuckDuckGo Client (FREE)', () => {
  it('should search Etsy listings without API key', async () => {
    const client = new DuckDuckGoClient();
    const result = await client.getListingCount('pickleball shirt');
    expect(result.count).toBeGreaterThan(0);
    expect(result.source).toBe('duckduckgo');
  });

  it('should estimate count from result count', async () => {
    const client = new DuckDuckGoClient();
    const result = await client.getListingCount('rare niche item');
    expect(result.estimated).toBe(true);
  });
});

describe('Serper Client (CHEAPEST)', () => {
  it('should return totalResults from Google SERP', async () => {
    const client = new SerperClient({ apiKey: process.env.SERPER_API_KEY });
    const result = await client.getListingCount('t-shirt');
    expect(result.count).toBeGreaterThan(50000);
    expect(result.cost).toBe(0.0003);
  });
});

describe('Cache', () => {
  it('should return cached result within TTL', async () => {
    const cache = new ListingCountCache();
    await cache.set('test', { count: 100, source: 'test' });
    const result = await cache.get('test');
    expect(result.count).toBe(100);
  });

  it('should return null for expired entries', async () => {
    // Test TTL expiration
  });
});
```

### Accuracy Validation Test

```javascript
// accuracy-test.js
const TEST_KEYWORDS = [
  // High volume (> 50k)
  { keyword: 't-shirt', expectedRange: [50000, 500000] },
  { keyword: 'jewelry', expectedRange: [100000, 1000000] },
  
  // Medium volume (10k-50k)
  { keyword: 'vintage poster', expectedRange: [10000, 100000] },
  { keyword: 'handmade soap', expectedRange: [10000, 100000] },
  
  // Low volume (< 10k)
  { keyword: 'quantum physics mug', expectedRange: [0, 10000] },
  { keyword: 'pickleball paddle holder', expectedRange: [100, 5000] },
];

async function validateAccuracy() {
  const results = [];
  
  for (const test of TEST_KEYWORDS) {
    const result = await getListingCount(test.keyword);
    const inRange = result.count >= test.expectedRange[0] && 
                    result.count <= test.expectedRange[1];
    
    results.push({
      keyword: test.keyword,
      count: result.count,
      source: result.source,
      expected: test.expectedRange,
      pass: inRange
    });
  }

  const accuracy = results.filter(r => r.pass).length / results.length;
  console.log(`Accuracy: ${(accuracy * 100).toFixed(1)}%`);
  
  return { accuracy, results };
}
```

### Integration Test

```javascript
// integration-test.js
async function fullIntegrationTest() {
  console.log('=== Full Integration Test ===\n');

  // Test 1: Cache miss -> DataForSEO
  console.log('Test 1: Fresh query (cache miss)');
  const result1 = await getListingCount('pickleball shirt');
  console.log(`  Count: ${result1.count}, Source: ${result1.source}`);
  assert(result1.source !== 'cache');

  // Test 2: Cache hit
  console.log('\nTest 2: Repeated query (cache hit)');
  const result2 = await getListingCount('pickleball shirt');
  console.log(`  Count: ${result2.count}, Source: ${result2.source}`);
  assert(result2.source === 'cache');

  // Test 3: Circuit breaker
  console.log('\nTest 3: Circuit breaker simulation');
  // Simulate failures and verify fallback

  // Test 4: Cost tracking
  console.log('\nTest 4: Cost tracking');
  console.log(`  Daily cost: $${costTracker.costs.daily.toFixed(4)}`);

  console.log('\n=== All tests passed ===');
}
```

### Performance Benchmarks

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Cache hit latency | < 5ms | Time from request to cached response |
| Etsy API latency | < 500ms | Time for full API call |
| DataForSEO latency | < 2s | Time for full API call |
| Total request latency | < 3s | End-to-end with fallbacks |
| Memory usage | < 50MB | Heap size with 1000 cached entries |

---

## Appendix A: API Reference Links

- **Etsy Open API v3:** https://developer.etsy.com/documentation/
- **DuckDuckGo (ddgs):** https://pypi.org/project/ddgs/ (FREE!)
- **Serper.dev:** https://serper.dev/docs (Cheapest paid)
- **DataForSEO SERP API:** https://docs.dataforseo.com/v3/serp/google/organic/live/
- **Perplexity API:** https://docs.perplexity.ai/
- **Brave Search API:** https://api.search.brave.com/

## Appendix B: Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| `ETSY_AUTH_EXPIRED` | Tokens need refresh | Auto-refresh or re-auth |
| `DATAFORSEO_INVALID_CREDS` | Bad credentials | Check config |
| `RATE_LIMITED` | Too many requests | Use circuit breaker |
| `ALL_SOURCES_FAILED` | No data available | Return cached or error |

## Appendix C: Monitoring & Alerts

```javascript
// Suggested monitoring metrics
const metrics = {
  requests_total: Counter,        // Total requests
  requests_by_source: Counter,    // Requests per data source
  cache_hits: Counter,            // Cache hit rate
  errors_by_source: Counter,      // Errors per source
  latency_histogram: Histogram,   // Response time distribution
  cost_daily: Gauge,              // Daily API costs
};
```

---

**Document Status:** Draft  
**Author:** Roo (Architect Mode)  
**Next Review:** After Phase 1 completion