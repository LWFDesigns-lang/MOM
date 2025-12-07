# Test Validation Checklist

Use this checklist to manually verify successful test mission execution.

## Pre-Test Verification

- [ ] `.claude/mcp-servers/logic-validator/index.js` exists
- [ ] `.claude/skills/pod-research/scripts/validate.py` exists
- [ ] `.claude/skills/pod-pricing/scripts/pricing.py` exists
- [ ] `.claude/skills/pod-design-review/prompts/style-guide.md` exists
- [ ] `.claude/memories/history.json` exists (empty array `[]` is OK)
- [ ] `.mcp.json` contains exactly 3 server configurations
- [ ] `.claude/CLAUDE.md` contains autonomous execution instructions
- [ ] Python is installed and accessible via `python` command
- [ ] Node.js is installed and accessible via `node` command

## Post-Test Verification

### History Persistence
- [ ] `.claude/memories/history.json` contains new entry
- [ ] Entry has `niche` field (should contain "pickleball" or similar)
- [ ] Entry has `validation_result` object
- [ ] Entry has `pricing` object  
- [ ] Entry has `design_concept` string
- [ ] Entry has `timestamp` field

### Tool Invocation Evidence
Review conversation transcript for evidence of:
- [ ] `read_history` was invoked (may show empty results if first run)
- [ ] `validate_niche` was invoked with market metrics
- [ ] `read_brand_voice` was invoked
- [ ] `calculate_price` was invoked for t-shirt
- [ ] `save_to_history` was invoked with analysis data

### Autonomous Behavior
- [ ] Claude did NOT ask for permission between steps
- [ ] Claude executed steps in logical sequence
- [ ] Claude adapted based on tool results
- [ ] Claude handled any errors gracefully

### Report Quality
- [ ] Report contains market overview section
- [ ] Report contains validation verdict (GO/SKIP)
- [ ] Report contains design concept description
- [ ] Report contains pricing with breakdown
- [ ] Report contains next steps section

### No Legacy References
Search Claude's responses for these terms (should NOT appear except in negation):
- [ ] No "docker" references (except saying "we don't use Docker")
- [ ] No "aws" references
- [ ] No "qdrant" references
- [ ] No "neo4j" references
- [ ] No "vector database" references
- [ ] No "graph database" references

## Test Result

Date: ________________
Tester: ________________

- [ ] **PASS** - All checklist items verified
- [ ] **PARTIAL PASS** - Core functionality works, minor issues noted
- [ ] **FAIL** - Critical issues prevent autonomous execution

### Notes
_Document any issues, observations, or recommendations:_