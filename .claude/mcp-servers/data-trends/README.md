# data-trends MCP Server

MCP server for retrieving Google Trends data with stability analysis for POD niche validation.

## Features

- **Hybrid Data Approach**: Primary data source is `google-trends-api` (free, unlimited)
- **24-Hour Caching**: Results cached for 24 hours to reduce API calls
- **Stability Score Calculation**: Analyzes trend volatility using coefficient of variation
- **Trend Direction Detection**: Identifies rising, stable, or declining trends
- **Configurable Timeframes**: Supports 3-month, 6-month, and 12-month analysis windows

## Installation

```bash
npm install
```

## Dependencies

- `@modelcontextprotocol/sdk` - MCP SDK for server implementation
- `google-trends-api` - Free Google Trends data access
- `node-cache` - In-memory caching with TTL

## Configuration

The server is configured in `.mcp.json`:

```json
{
  "data-trends": {
    "command": "node",
    "args": [".claude/mcp-servers/data-trends/index.js"],
    "cwd": "/home/docker/MOM"
  }
}
```

### Optional API Keys (Fallbacks)

While not required, these can be added for enhanced fallback capabilities:

```bash
SERPAPI_KEY=your_key_here          # SerpAPI (250 free/month)
DATAFORSEO_LOGIN=your_login        # DataForSEO (pay-per-use)
DATAFORSEO_PASSWORD=your_password
```

## Available Tools

### `trends_get_stability`

Retrieves trend stability score and metrics for a keyword.

**Input:**
```javascript
{
  keyword: string,              // Required: The niche keyword to analyze
  timeframe: "3mo" | "6mo" | "12mo"  // Optional: Analysis window (default: "12mo")
}
```

**Output:**
```javascript
{
  keyword: string,              // The analyzed keyword
  stability_score: number,      // 0-1 score (higher = more stable)
  trend_direction: string,      // "rising" | "stable" | "declining"
  average_interest: number,     // Mean interest level (0-100)
  current_interest: number,     // Most recent interest level
  data_points: number,          // Number of data points analyzed
  source: string,               // "google-trends-api" | "cache" | "fallback"
  timestamp: string,            // ISO 8601 timestamp
  error?: string                // Optional error message if fallback used
}
```

## Stability Score Calculation

The stability score uses **coefficient of variation** (CV):

1. Calculate mean and standard deviation of interest values
2. Compute CV = stdDev / mean
3. Convert to stability score: `1 - CV` (clamped to 0-1)

**Interpretation:**
- `0.8-1.0`: Very stable trend (low volatility)
- `0.6-0.8`: Moderately stable
- `0.4-0.6`: Moderate volatility
- `0.0-0.4`: High volatility (unstable)

## Trend Direction Logic

Compares average interest in first half vs second half:

- **Rising**: Second half average > 15% higher
- **Declining**: Second half average > 15% lower  
- **Stable**: Change within ±15%

## Caching Strategy

- **Cache Key**: `trend:${keyword}:${timeframe}`
- **TTL**: 24 hours (86400 seconds)
- **Behavior**: Returns cached data immediately if available

## Error Handling

1. Try `google-trends-api` with 3 attempts
2. Use exponential backoff on rate limits (5s, 10s, 20s)
3. Fall back to synthetic data if all attempts fail

**Fallback Response:**
```javascript
{
  stability_score: 0.5,
  trend_direction: "stable",
  average_interest: 50,
  current_interest: 50,
  source: "fallback",
  error: "Unable to fetch trend data, using default values"
}
```

## Testing

Run the test suite:

```bash
node test.js
```

The test verifies:
- Server initialization
- Tool listing
- Trend data retrieval for multiple timeframes
- Response format validation

## Debug Mode

Enable debug logging:

```bash
DEBUG_MCP=1 node index.js
```

## Example Usage

```javascript
// Via MCP tool call
{
  "method": "tools/call",
  "params": {
    "name": "trends_get_stability",
    "arguments": {
      "keyword": "pickleball",
      "timeframe": "12mo"
    }
  }
}

// Response
{
  "keyword": "pickleball",
  "stability_score": 0.88,
  "trend_direction": "stable",
  "average_interest": 79,
  "current_interest": 67,
  "data_points": 54,
  "source": "google-trends-api",
  "timestamp": "2025-12-07T21:16:58.363Z"
}
```

## Integration with POD Workflow

This server integrates with the `logic-validator` MCP server for niche validation:

1. `logic-validator` validates niche viability thresholds
2. `data-trends` provides trend stability data
3. Combined analysis determines GO/SKIP recommendation

## Architecture

- **Protocol**: MCP 2.0 (JSON-RPC over stdio)
- **Transport**: Standard input/output
- **Format**: Line-delimited JSON
- **Language**: ES Modules (Node.js 18+)

## License

Part of the MOM (Market Opportunity Mapper) project.