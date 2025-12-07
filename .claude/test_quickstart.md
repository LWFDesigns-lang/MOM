# Test Mission Quick Start

## How to Run the Test

1. **Ensure Prerequisites**
   - Python 3.x installed (`python --version`)
   - Node.js 18+ installed (`node --version`)
   - Brave Search API key configured (optional, test proceeds with limitations if missing)

2. **Start a New Claude Session**
   - Open Claude Desktop or Claude in your IDE
   - Ensure the MCP servers are connected (check for tool availability)

3. **Present the Mission**
   Copy and paste the contents of `.claude/test_mission.md` to Claude.
   
   Or simply state: "Research the pickleball niche for POD opportunities"

4. **Observe Execution**
   - Watch for autonomous tool invocations
   - Note the sequence of tools used
   - Check that Claude doesn't pause for permission

5. **Verify Results**
   - Check `.claude/memories/history.json` for new entry
   - Use `.claude/test_validation_checklist.md` for thorough verification
   - Compare against `.claude/test_expected_outcomes.md`

## Expected Duration
A complete test run should take approximately 2-5 minutes depending on search response times.

## Troubleshooting

### "Tool not found" errors
- Verify `.mcp.json` is correctly configured
- Restart Claude/IDE to reload MCP connections
- Check Node.js and Python are in PATH

### Python script errors
- Run scripts manually to verify:
  ```bash
  python .claude/skills/pod-research/scripts/validate.py '{"niche":"test","etsy_count":1000,"trend_score":0.5}'
  ```

### Empty search results
- If Brave Search fails, test proceeds with mock data
- Verify BRAVE_API_KEY environment variable is set

### History not updating
- Check write permissions on `.claude/memories/`
- Verify history.json is valid JSON (at minimum `[]`)