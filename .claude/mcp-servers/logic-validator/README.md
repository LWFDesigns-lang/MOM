# Logic Validator MCP Server

An MCP 2.0 compliant server that exposes POD (Print on Demand) business logic validation tools through the Model Context Protocol. This server acts as the "glue" layer in the Lean Agent MVP architecture, connecting Claude Desktop to Python-based business logic scripts.

## Architecture

```
┌─────────────────┐
│  Claude Desktop │
└────────┬────────┘
         │ MCP 2.0 (stdio)
         │ JSON-RPC
         ▼
┌─────────────────────────┐
│ Logic Validator Server  │
│   (Node.js/stdio)       │
├─────────────────────────┤
│ • validate_niche        │─────► Python: validate.py
│ • calculate_price       │─────► Python: pricing.py
│ • read_brand_voice      │─────► File: style-guide.md
│ • save_to_history       │─────► JSON: history.json
│ • read_history          │─────► JSON: history.json
└─────────────────────────┘
```

## Available Tools

### 1. `validate_niche`
Validates POD niche viability using market metrics and business logic thresholds.

**Input:**
```json
{
  "niche": "pickleball",
  "etsy_count": 1500,
  "trend_score": 0.65
}
```

**Output:**
```json
{
  "valid": true,
  "confidence": "high",
  "concerns": [],
  "recommendation": "proceed",
  "reasoning": "Strong opportunity: Moderate competition (1500 listings) with strong trend (65.0%); Growing market with strong interest"
}
```

**Business Logic:**
- Analyzes Etsy competition levels (low <1K, moderate 1-10K, high >10K)
- Evaluates Google Trends score against market vitality thresholds
- Returns actionable GO/SKIP recommendation with confidence level

### 2. `calculate_price`
Calculates recommended pricing for POD products with fee structure and profit margins.

**Input:**
```json
{
  "product_type": "t-shirt"
}
```

**Output:**
```json
{
  "product_type": "t-shirt",
  "base_cost": 12.00,
  "recommended_price": 24.99,
  "minimum_price": 22.99,
  "profit_margin_percent": 42.5,
  "cost_breakdown": {
    "production": 12.00,
    "platform_fees_estimate": 5.62,
    "profit_at_recommended": 7.37
  }
}
```

**Supported Products:**
- `t-shirt`, `hoodie`, `mug`, `poster`, `sticker`, `tote-bag`

### 3. `read_brand_voice`
Retrieves brand style guide documentation for on-brand design generation.

**Input:**
```json
{
  "brand": "lwf"
}
```

**Output:**
Full text content of the style guide including:
- Brand overview and positioning
- Color palettes and typography guidelines
- Design composition rules
- Approved motifs and themes
- Quality checklists

### 4. `save_to_history`
Persists research and validation results to local history for future reference.

**Input:**
```json
{
  "data": {
    "niche": "pickleball",
    "validation_result": { "valid": true, "confidence": "high" },
    "pricing": { "recommended_price": 24.99 },
    "design_concept": "Minimalist pickleball paddle illustration...",
    "timestamp": "2025-12-07T16:22:00.000Z"
  }
}
```

**Output:**
```json
{
  "success": true,
  "message": "Saved entry for niche: pickleball",
  "timestamp": "2025-12-07T16:22:00.000Z",
  "total_entries": 5
}
```

**Note:** Timestamp is auto-added if not provided.

### 5. `read_history`
Retrieves previous research runs with optional filtering and limiting.

**Input:**
```json
{
  "niche_filter": "pickle",
  "limit": 10
}
```

**Output:**
```json
{
  "total_found": 3,
  "returned": 3,
  "entries": [
    {
      "niche": "pickleball",
      "validation_result": { "valid": true },
      "timestamp": "2025-12-07T16:22:00.000Z"
    }
  ]
}
```

**Features:**
- Case-insensitive substring matching on niche names
- Sort by timestamp descending (most recent first)
- Configurable result limit (default: 10)

## Installation & Setup

### Prerequisites

1. **Node.js** v18.0.0 or higher
   ```bash
   node --version
   ```

2. **Python 3** with required scripts
   ```bash
   python --version
   ```

3. **Project Structure**
   The server expects the following workspace structure:
   ```
   workspace/
   ├── .claude/
   │   ├── mcp-servers/
   │   │   └── logic-validator/
   │   │       ├── index.js          # This server
   │   │       ├── package.json
   │   │       └── README.md
   │   ├── skills/
   │   │   ├── pod-research/
   │   │   │   └── scripts/
   │   │   │       └── validate.py
   │   │   ├── pod-pricing/
   │   │   │   └── scripts/
   │   │   │       └── pricing.py
   │   │   └── pod-design-review/
   │   │       └── prompts/
   │   │           └── style-guide.md
   │   └── memories/
   │       └── history.json
   ```

### Installation

No external dependencies required. The server uses only Node.js built-in modules:
- `readline` - stdio transport
- `child_process` - Python script execution
- `fs/promises` - file operations
- `path` - path resolution

## Running the Server

### Manual Execution (Testing)

From the server directory:
```bash
cd .claude/mcp-servers/logic-validator
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | node index.js
```

Expected output:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": { "tools": {} },
    "serverInfo": { "name": "logic-validator", "version": "1.0.0" }
  }
}
```

### Testing Individual Tools

**List available tools:**
```bash
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | node index.js
```

**Test validate_niche:**
```bash
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"validate_niche","arguments":{"niche":"pickleball","etsy_count":1500,"trend_score":0.65}}}' | node index.js
```

**Test calculate_price:**
```bash
echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"calculate_price","arguments":{"product_type":"t-shirt"}}}' | node index.js
```

### Integration with Claude Desktop

Add to your Claude Desktop MCP configuration (`.mcp.json` or `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "logic-validator": {
      "command": "node",
      "args": ["/absolute/path/to/.claude/mcp-servers/logic-validator/index.js"],
      "env": {}
    }
  }
}
```

## Error Handling

The server implements comprehensive error handling:

### Python Script Errors
- **Script not found**: Returns clear path error
- **Python not available**: Returns spawn error with instructions
- **Invalid JSON output**: Returns parse error with actual output
- **Script execution failure**: Returns exit code and stderr

### File Operation Errors
- **History file missing**: Auto-creates empty array
- **Invalid JSON in history**: Returns empty array
- **Write permission issues**: Returns filesystem error

### Protocol Errors
- **Malformed JSON-RPC**: Returns `-32700` parse error
- **Unknown method**: Returns `-32000` with method name
- **Unknown tool**: Returns `-32000` with tool name
- **Missing parameters**: Returns `-32602` invalid params

All errors are logged to stderr (not stdout) to preserve JSON-RPC protocol integrity.

## Development Notes

### Transport Protocol
- Uses **stdio transport** (line-delimited JSON-RPC)
- **stdin**: Reads JSON-RPC requests
- **stdout**: Writes JSON-RPC responses
- **stderr**: Logs errors and debugging info

### Path Resolution
All file paths are resolved relative to the workspace root (3 levels up from `index.js`):
```javascript
const WORKSPACE_ROOT = resolve(__dirname, '../../..');
```

This ensures the server works regardless of where it's executed from.

### History File Format
```json
[
  {
    "niche": "pickleball",
    "validation_result": { "valid": true, "confidence": "high" },
    "pricing": { "recommended_price": 24.99 },
    "design_concept": "...",
    "timestamp": "2025-12-07T16:22:00.000Z"
  }
]
```

## Troubleshooting

### Common Issues

**"python: command not found"**
- Ensure Python 3 is installed and in PATH
- Try `python3` instead: modify spawn command in `index.js`

**"Script exited with code 1"**
- Check Python script exists at expected path
- Verify script has correct input format
- Review stderr output for Python errors

**"Invalid JSON output"**
- Python script may be outputting debug info to stdout
- Ensure scripts only print JSON to stdout
- Debug output should go to stderr

**"No such file or directory"**
- Verify workspace structure matches expected layout
- Check file paths in `index.js` constants
- Ensure scripts are executable

**MCP Server Not Appearing in Claude Desktop**
- Verify `.mcp.json` configuration
- Use absolute paths, not relative
- Restart Claude Desktop after config changes
- Check Claude Desktop logs for errors

## License

MIT

## Version

**Server Version:** 1.0.0  
**MCP Protocol:** 2024-11-05  
**Last Updated:** 2025-12-07