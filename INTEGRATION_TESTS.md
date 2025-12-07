# POD Automation Integration Tests

**Version:** 1.0  
**Last Updated:** 2025-12-07  
**Environment:** Windows 11 / Linux Compatible

## Overview

This document provides comprehensive integration testing and verification procedures for the POD automation system. All components have been implemented and must be tested to ensure correct operation both individually and as an integrated system.

## Test Categories

### 1. Component-Level Tests

Test each component independently to verify basic functionality.

#### MCP Servers

**Filesystem MCP:**
```bash
# Test file creation
echo '{"test": "data"}' > .claude/data/test.json

# Verify file exists
cat .claude/data/test.json

# Expected: {"test": "data"}
```

**Brave Search MCP (if configured):**
```bash
# Test API connectivity
# Use Claude to invoke: "Search for 'POD trends 2024'"
# Expected: Search results returned
```

**Docker Services:**
```bash
# Check Qdrant vector database
docker ps | grep qdrant
# Expected: Container running

# Check Neo4j graph database
docker ps | grep neo4j
# Expected: Container running

# Test Qdrant health endpoint
curl http://127.0.0.1:6333/health
# Expected: {"status":"ok"}

# Test Neo4j (optional, requires auth)
curl http://127.0.0.1:7474
# Expected: Neo4j browser page
```

#### Skills

**pod-research skill:**
```bash
# Test niche validation with GO decision
python3 .claude/skills/pod-research/scripts/validate.py "indoor plant care" 18500 62

# Expected Output:
# {
#   "decision": "GO",
#   "confidence": 0.75,
#   "reasoning": "...",
#   "niche": "indoor plant care",
#   "competition_score": 62,
#   "demand_score": 18500
# }

# Test with SKIP decision (oversaturated)
python3 .claude/skills/pod-research/scripts/validate.py "funny cat" 95000 88

# Expected Output:
# {
#   "decision": "SKIP",
#   "confidence": 0.82,
#   "reasoning": "Competition too high...",
#   ...
# }
```

**pod-pricing skill:**
```bash
# Test standard tee pricing
python3 .claude/skills/pod-pricing/scripts/pricing.py "tee_standard"

# Expected Output:
# {
#   "product_type": "tee_standard",
#   "base_cost": 12.50,
#   "printful_fee": 2.50,
#   "total_cost": 15.00,
#   "target_margin": 0.60,
#   "recommended_price": 34.99,
#   "actual_margin": 0.571,
#   "profit_per_unit": 19.99
# }

# Test hoodie pricing
python3 .claude/skills/pod-pricing/scripts/pricing.py "hoodie_standard"

# Expected: Price ~$54.99 with margin breakdown
```

**pod-listing-seo skill:**
```bash
# Test SEO validation
python3 .claude/skills/pod-listing-seo/scripts/validate_seo.py \
  "Indoor Plant Care Tee - Organic Cotton Gift for Plant Lovers" \
  '["plant lover","organic cotton","plant care","indoor plants","gardening gift"]' \
  "Show your love for indoor plants with this premium organic cotton tee. Perfect for plant parents and gardening enthusiasts. Features eco-friendly materials and comfortable fit. Great gift for plant lovers who care about sustainability."

# Expected Output:
# {
#   "seo_score": 85,
#   "title_quality": "excellent",
#   "keywords_used": 4,
#   "description_length": 245,
#   "recommendations": [...]
# }
```

**pod-design-review skill:**
```bash
# Manual test via Claude interface
# Trigger: "Review design concepts for validated niche 'minimalist plant care' using LWF brand voice"

# Expected: 
# - Loads brand_voice_lwf.md from memories
# - Generates 5 design concepts
# - Ranks by brand alignment
# - Provides visual prompts for each
```

**memory-manager skill:**
```bash
# Test saving to validated niches
# Trigger via Claude: "Save this niche: minimalist plant care, GO decision, conf 0.78"

# Verify file updated
cat .claude/memories/validated_niches.json

# Expected: New entry appended with timestamp
```

#### Context Management

**Context Monitoring:**
```bash
# Test token counting
bash .claude/scripts/context-manager.sh

# Expected Output:
# Current context: 45,234 tokens
# Limit: 180,000 tokens
# Usage: 25.1%
# Status: NORMAL
```

**Checkpoint Creation:**
```bash
# Create checkpoint
bash .claude/scripts/checkpoint-manager.sh create "test_checkpoint"

# Expected Output:
# Checkpoint 'test_checkpoint' created successfully
# Location: .claude/checkpoints/test_checkpoint_[timestamp].json

# List checkpoints
bash .claude/scripts/checkpoint-manager.sh list

# Expected: List of available checkpoints

# Restore checkpoint
bash .claude/scripts/checkpoint-manager.sh restore "test_checkpoint"

# Expected: State restored confirmation
```

### 2. Integration Tests

Test component interactions and data flow between systems.

#### Skill → MCP Integration

**Test Data Flow:**
```markdown
Scenario: pod-research skill calls data-etsy MCP
- Trigger: Niche validation request
- Process:
  1. validate.py executes
  2. Calls data-etsy MCP for competition count
  3. Calls data-trends MCP for trend score
  4. Processes results through logic
- Verification: Check that API calls succeed and data flows correctly
- Expected Token Cost: 1.5-2K tokens
```

**Test Custom MCP (if implemented):**
```markdown
Scenario: Results feed into logic-validator MCP
- Process:
  1. Validation results sent to logic-validator
  2. MCP applies additional business rules
  3. Decision refined based on custom logic
- Verification: Enhanced decision accuracy
```

#### Skill → Memory Integration

**Test Memory Persistence:**
```markdown
Scenario: pod-design-review loads brand voice
- Trigger: "Generate designs for [niche] using LWF brand"
- Process:
  1. Skill triggered
  2. Reads .claude/memories/brand_voice_lwf.md
  3. Applies brand guidelines to concepts
  4. Generates aligned designs
- Verification: Designs match brand voice characteristics
- Expected Token Cost: 5-8K tokens
```

**Test Memory Saving:**
```markdown
Scenario: memory-manager saves validated niche
- Trigger: Successful niche validation
- Process:
  1. Hook triggers on skill completion
  2. memory-manager skill activates
  3. Appends to validated_niches.json
  4. Includes timestamp and metadata
- Verification: JSON file contains new entry
- Expected Token Cost: 100-200 tokens
```

#### Workflow → Skill Chains

**Test Sequential Execution:**
```markdown
Scenario: full_pipeline.yaml workflow
- Process:
  1. Research & validate niche
  2. Generate designs (if GO)
  3. Calculate pricing
  4. Create SEO listing
- Verification: Each step completes before next starts
- Checkpoints: Created at phase boundaries
- Expected Token Cost: 8-12K tokens
- Expected Time: ~40 minutes
```

**Test Parallel Execution (if applicable):**
```markdown
Scenario: Batch processing multiple niches
- Process:
  1. Queue 5 niches
  2. Validate in parallel (if configured)
  3. Aggregate results
- Verification: All validations complete
- Expected Token Cost: 7-12K tokens (shared context)
```

### 3. End-to-End Workflow Tests

Complete POD workflow simulations from start to finish.

#### Test 1: Single Niche Validation

**Input:**
```
Niche: "minimalist plant care"
Competition: 18,500 listings
Trend Score: 62
```

**Process:**
1. Trigger pod-research skill
2. MCP calls for Etsy data
3. MCP calls for trends data
4. validate.py executes business logic
5. GO/SKIP decision generated
6. Result saved to validated_niches.json

**Expected Output:**
```json
{
  "decision": "GO",
  "confidence": 0.75,
  "reasoning": "Moderate competition with growing trend. Sweet spot for entry.",
  "niche": "minimalist plant care",
  "competition_score": 62,
  "demand_score": 18500,
  "timestamp": "2025-12-07T06:00:00Z"
}
```

**Token Cost:** 1.5-2.5K tokens  
**Time:** ~2-3 minutes

#### Test 2: Design Generation

**Input:**
```
Validated Niche: "minimalist plant care"
Brand: Living With Flair (LWF)
```

**Process:**
1. Trigger pod-design-review skill
2. Load brand_voice_lwf.md from memories
3. Generate 5 design concepts
4. Apply brand guidelines
5. Rank concepts by brand fit
6. Provide visual prompts

**Expected Output:**
```markdown
# Design Concepts for "minimalist plant care" - LWF Brand

## Concept 1: "Simple Plant Parent" (Brand Fit: 95%)
Visual: Line art of single potted plant, serif typography
Colors: Sage green, cream, charcoal
Prompt: "Minimalist line drawing of a monstera plant in terracotta pot..."

## Concept 2: "Geometric Growth" (Brand Fit: 88%)
...

[5 concepts total with visual prompts, brand scoring]
```

**Token Cost:** 5-8K tokens  
**Time:** ~8-12 minutes

#### Test 3: Full Pipeline Execution

**Input:**
```
New Niche: "sustainable gardening tools"
```

**Process:**
1. **Research Phase:**
   - Validate niche viability
   - Decision: GO (conf 0.71)
   
2. **Design Phase:**
   - Generate 5 concepts
   - Select top 2 for production
   
3. **Pricing Phase:**
   - Calculate for tee_standard
   - Recommended: $34.99
   
4. **Listing Phase:**
   - Generate SEO-optimized title
   - Create 300-word description
   - Extract 13 keywords

**Expected Output:**
Complete Etsy listing draft ready for publication.

**Token Cost:** 8-12K tokens  
**Time:** ~35-45 minutes

### 4. Performance Benchmarks

Measure actual performance against architectural specifications.

#### Benchmark Tests

| Operation | Expected Tokens | Expected Time | Actual Tokens | Actual Time | Pass/Fail |
|-----------|----------------|---------------|---------------|-------------|-----------|
| Single niche validation | 1.5-2.5K | 2-3 min | ___ | ___ | ___ |
| Design generation (5 concepts) | 5-8K | 8-12 min | ___ | ___ | ___ |
| Pricing calculation | 100-150 | <1 min | ___ | ___ | ___ |
| SEO listing creation | 2-3K | 4-6 min | ___ | ___ | ___ |
| Full pipeline (single niche) | 8-12K | 35-45 min | ___ | ___ | ___ |
| Batch validation (5 niches) | 7-12K | 10-15 min | ___ | ___ | ___ |
| Batch full pipeline (3 niches) | 25-30K | 2-3 hours | ___ | ___ | ___ |

#### Performance Criteria

**PASS Criteria:**
- Token usage within ±20% of expected
- Time within ±30% of expected
- All steps complete successfully
- Output quality meets standards

**FAIL Criteria:**
- Token usage >50% over expected
- Time >100% over expected
- Any step fails or errors
- Output quality below acceptable

### 5. Security Verification

Audit security implementation and compliance.

#### API Key Security

```bash
# Verify NO static API keys in .env
grep -i "key.*=" .env | grep -v "VAULT" | grep -v "EXAMPLE"

# Expected: No matches (all keys in AWS Secrets Manager)

# Verify .env.example only contains placeholders
cat .env.example | grep -i "key"

# Expected: Only VAULT_PATH references, no actual keys
```

#### MCP Security Configuration

```bash
# Verify OAuth-only configuration
cat .mcp.json | jq '.security_compliance'

# Expected Output:
# {
#   "auth_method": "oauth_only",
#   "key_retrieval": "jit",
#   "static_keys": false
# }

# Check for hardcoded credentials
grep -r "api_key\|password\|secret" .mcp.json

# Expected: No matches
```

#### Docker Network Isolation

```bash
# Verify localhost-only binding
docker inspect qdrant-pod | grep "127.0.0.1"

# Expected: All ports bound to 127.0.0.1

docker inspect neo4j-pod | grep "127.0.0.1"

# Expected: All ports bound to 127.0.0.1

# Verify no exposed external ports
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "127.0.0.1"

# Expected: No output (all ports local only)
```

#### File Permission Audit

```bash
# Verify sensitive files are not world-readable (Linux)
ls -la .env .claude/memories/*.json

# Expected: Permissions 600 or 644 (owner only or owner+group)

# Verify scripts are executable
ls -la .claude/scripts/*.sh

# Expected: Permissions include execute bit (755 or 750)
```

### 6. Failure & Recovery Tests

Test error handling and graceful degradation.

#### MCP Connection Failure

**Scenario: Network Disconnection**
```bash
# Simulate by stopping Docker services
docker stop qdrant-pod neo4j-pod

# Attempt niche validation
python3 .claude/skills/pod-research/scripts/validate.py "test niche" 20000 60

# Expected Behavior:
# - Fallback to cached data (if available)
# - Graceful error message (if no cache)
# - Entry added to escalation queue
# - Script exits with code 1

# Restore services
docker start qdrant-pod neo4j-pod

# Verify recovery
curl http://127.0.0.1:6333/health
```

#### Context Limit Approaching

**Scenario: Token Limit Escalation**
```bash
# Simulate high context usage (manual test via Claude)
# Add large amount of content to conversation

# Trigger context monitor
bash .claude/scripts/context-manager.sh

# Expected Behavior at 140K tokens:
# - Warning message displayed
# - Microcompact mode suggested
# - Checkpoint creation recommended

# Expected Behavior at 170K tokens:
# - CRITICAL alert
# - Automatic microcompact trigger
# - Token savings >40%
# - Essential context preserved
```

#### Checkpoint Restore

**Scenario: Mid-Operation Failure**
```bash
# Create checkpoint before operation
bash .claude/scripts/checkpoint-manager.sh create "pre_batch_test"

# Start batch operation (simulate failure partway)
# [Manually interrupt or simulate crash]

# Restore from checkpoint
bash .claude/scripts/checkpoint-manager.sh restore "pre_batch_test"

# Expected Behavior:
# - State restored to pre-operation
# - Conversation context recovered
# - Memory files reverted
# - Ready to retry operation
```

#### Skill Execution Failure

**Scenario: Python Script Error**
```bash
# Test with invalid input
python3 .claude/skills/pod-research/scripts/validate.py "test" "invalid" "data"

# Expected Behavior:
# - Error message displayed
# - Exit code 1
# - JSON error response (if applicable)
# - No partial data written

# Verify no corruption
cat .claude/memories/validated_niches.json | jq '.'

# Expected: Valid JSON structure maintained
```

### 7. Cross-Platform Compatibility

Test on Windows and Linux environments.

#### Windows PowerShell Tests

```powershell
# Test MCP health check (Windows)
# If .sh script, requires WSL or Git Bash
bash mcp-health-check.sh

# Alternative: Create .ps1 version
.\mcp-health-check.ps1

# Test context manager
.\\.claude\scripts\context-manager.ps1

# Test Python skills (Windows paths)
python .claude\skills\pod-research\scripts\validate.py "test" 20000 60

# Expected: All scripts execute successfully
```

#### Linux/macOS Bash Tests

```bash
# Test MCP health check (Linux/Mac)
bash mcp-health-check.sh

# Expected: All checks pass

# Test context manager
bash .claude/scripts/context-manager.sh

# Test Python skills (Unix paths)
python3 .claude/skills/pod-research/scripts/validate.py "test" 20000 60

# Expected: All scripts execute successfully
```

#### Path Compatibility

**Verification Checklist:**
- [ ] Python scripts use `os.path.join()` for paths
- [ ] Shell scripts use forward slashes or variables
- [ ] No hardcoded Windows-specific paths (C:\...)
- [ ] No hardcoded Unix-specific paths (/Users/...)
- [ ] All scripts have proper line endings (LF for bash, CRLF for .ps1)

### 8. Hooks & Automation Tests

Test automated triggers and integrations.

#### Post-Skill Completion Hooks

**Test Automatic Memory Saving:**
```bash
# Trigger skill that should activate hook
# Example: Successful niche validation

# Verify hook executed
cat .claude/hooks/post-skill-complete.json

# Expected: Hook configuration present

# Verify action taken
cat .claude/memories/validated_niches.json

# Expected: New entry appended automatically
```

#### Workflow Automation

**Test Scheduled Execution (if configured):**
```bash
# Check cron jobs or scheduled tasks
crontab -l  # Linux/Mac

# Windows: Check Task Scheduler
# Get-ScheduledTask | Where-Object {$_.TaskName -like "*POD*"}

# Verify automation configs
cat .claude/automation/*.yaml

# Expected: Valid workflow definitions
```

## Test Execution Scripts

Automated test runners are located in `.claude/tests/`.

### Running All Tests

```bash
# Execute complete test suite
bash .claude/tests/run-all-tests.sh

# Expected: Full test report generated
# Results saved to: .claude/tests/TEST_RESULTS.md
```

### Running Individual Test Suites

```bash
# Component tests only
bash .claude/tests/test-mcps.sh
bash .claude/tests/test-skills.sh

# Integration tests
bash .claude/tests/test-end-to-end.sh

# Performance benchmarks
bash .claude/tests/benchmark-performance.sh

# Security audit
bash .claude/tests/audit-security.sh
```

## Verification Checklist

### Phase 0: Foundation
- [ ] Directory structure created correctly
- [ ] CLAUDE.md exists with 200+ lines
- [ ] Brand voice files created (2 brands minimum)
- [ ] JSON stores initialized (validated_niches.json, etc.)
- [ ] Config files in place (.env.example, etc.)

### Phase 1: Skills System
- [ ] All 5 skills have SKILL.md files
- [ ] Python scripts execute without errors
- [ ] validate.py returns valid JSON
- [ ] pricing.py calculates correctly
- [ ] Skills trigger on expected phrases

### Phase 2: MCP Integration
- [ ] .mcp.json is valid JSON
- [ ] MCP packages installed successfully
- [ ] Docker services running (qdrant, neo4j)
- [ ] `claude /mcp` shows connected servers
- [ ] OAuth JIT configured (no static keys)

### Phase 3: Automation
- [ ] Hooks configuration valid JSON
- [ ] Skill chains defined correctly
- [ ] Subagents configured
- [ ] Workflows executable
- [ ] Fallback chains working

### Phase 4: Context Management
- [ ] Context monitoring scripts work
- [ ] Checkpoint creation/restore works
- [ ] Token budgets enforced
- [ ] Microcompact triggers correctly

### Phase 5: Integration
- [ ] Skills call MCPs successfully
- [ ] Memory persistence works
- [ ] Hooks trigger automatically
- [ ] Full pipeline completes
- [ ] Token costs within budgets

### Phase 6: Security
- [ ] No static API keys in .env
- [ ] OAuth-only MCP configuration
- [ ] Docker ports localhost-only
- [ ] Sensitive files protected
- [ ] Secrets in AWS Secrets Manager

### Phase 7: Performance
- [ ] Token usage within expected ranges
- [ ] Execution times reasonable
- [ ] No memory leaks
- [ ] Efficient context usage
- [ ] Batch operations optimized

## Test Results Documentation

All test results should be documented in `.claude/tests/TEST_RESULTS.md`.

See template in that file for proper documentation format.

## Troubleshooting Guide

### Common Issues

**Issue: MCP server not connecting**
- Check Docker services: `docker ps`
- Verify ports: `netstat -an | grep 6333`
- Check .mcp.json configuration
- Review mcp-health-check.sh output

**Issue: Python script errors**
- Verify Python 3.8+ installed: `python3 --version`
- Check dependencies: `pip3 list`
- Review script execution permissions
- Check file paths (Windows vs Linux)

**Issue: Context limit warnings**
- Run context-manager.sh
- Create checkpoint before continuing
- Consider microcompact mode
- Review conversation length

**Issue: Checkpoint restore fails**
- Verify checkpoint exists: `ls .claude/checkpoints/`
- Check JSON validity: `jq '.' checkpoint_file.json`
- Ensure proper permissions
- Review error messages

## Success Criteria

Testing is considered successful when:

1. **All component tests pass** (100% success rate)
2. **Integration tests demonstrate proper data flow**
3. **End-to-end workflows complete successfully**
4. **Performance benchmarks within acceptable ranges**
5. **Security audit shows zero vulnerabilities**
6. **Error recovery tests demonstrate resilience**
7. **Cross-platform compatibility confirmed**
8. **Documentation accurately reflects system behavior**

## Next Steps After Testing

1. **Document any issues found** in TEST_RESULTS.md
2. **Create bug reports** for any failures
3. **Update architecture** if design changes needed
4. **Optimize performance** based on benchmarks
5. **Enhance security** if vulnerabilities found
6. **Update user guides** with testing insights

## Continuous Integration

For ongoing development:

1. **Run tests before commits** (pre-commit hook)
2. **Automated testing on merge** (CI/CD pipeline)
3. **Regular security audits** (weekly/monthly)
4. **Performance regression tests** (with each update)

## Reference Documentation

- Architecture: [`SETUP_GUIDE_ARCHITECTURE.md`](SETUP_GUIDE_ARCHITECTURE.md)
- Feature Inventory: [`CLAUDE_CODE_2.0_FEATURE_INVENTORY.md`](CLAUDE_CODE_2.0_FEATURE_INVENTORY.md)
- Setup Guide: [`CLAUDE_CODE_2.0_POD_BUSINESS_SETUP_GUIDE.md`](CLAUDE_CODE_2.0_POD_BUSINESS_SETUP_GUIDE.md)
- MCP Installation: [`mcp-installation-guide.md`](mcp-installation-guide.md)
- Security Configuration: [`security-config.md`](security-config.md)

---

**Document Version:** 1.0  
**Maintenance:** Update after significant system changes  
**Review Cycle:** Quarterly or after major updates