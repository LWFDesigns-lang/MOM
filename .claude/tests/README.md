# POD Automation Test Suite

Comprehensive integration testing and verification system for the POD automation project.

## Quick Start

### Linux / macOS

```bash
# Make scripts executable
chmod +x .claude/tests/*.sh

# Run all tests
bash .claude/tests/run-all-tests.sh

# Run individual test suites
bash .claude/tests/test-skills.sh
bash .claude/tests/test-mcps.sh
bash .claude/tests/test-workflows.sh
bash .claude/tests/test-end-to-end.sh
bash .claude/tests/benchmark-performance.sh
bash .claude/tests/audit-security.sh
```

### Windows

**Option 1: WSL (Recommended)**
```powershell
# Run via Windows Subsystem for Linux
wsl bash .claude/tests/run-all-tests.sh
```

**Option 2: Git Bash**
```bash
# Run via Git Bash terminal
bash .claude/tests/run-all-tests.sh
```

**Option 3: PowerShell (Manual)**
```powershell
# Test scripts individually using PowerShell
python .claude/skills/pod-research/scripts/validate.py "test niche" 20000 60
python .claude/skills/pod-pricing/scripts/pricing.py "tee_standard"
# See INTEGRATION_TESTS.md for full command reference
```

## Test Suite Overview

### 1. Master Test Runner
**File:** `run-all-tests.sh`  
**Purpose:** Executes all test categories and generates comprehensive report  
**Output:** Test results in `TEST_RESULTS.md` and log file

### 2. Skills Tests
**File:** `test-skills.sh`  
**Tests:**
- pod-research validation (GO/SKIP decisions)
- pod-pricing calculations
- pod-listing-seo validation
- SKILL.md file completeness
- Trigger phrase definitions

### 3. MCP Tests
**File:** `test-mcps.sh`  
**Tests:**
- .mcp.json configuration
- Docker service health (Qdrant, Neo4j)
- Filesystem MCP operations
- Security compliance settings
- Network port bindings

### 4. Workflow Tests
**File:** `test-workflows.sh`  
**Tests:**
- Workflow YAML syntax
- Subagent configurations
- Hook definitions
- Skill chain configurations
- Context management scripts

### 5. End-to-End Tests
**File:** `test-end-to-end.sh`  
**Tests:**
- Complete niche validation flow
- Pricing calculation pipeline
- SEO listing generation
- Memory persistence
- Full pipeline simulation
- Error handling

### 6. Performance Benchmarks
**File:** `benchmark-performance.sh`  
**Measures:**
- Token usage per operation
- Execution time benchmarks
- Memory I/O performance
- Docker service response times
- Batch processing efficiency

### 7. Security Audit
**File:** `audit-security.sh`  
**Audits:**
- API key exposure
- MCP security configuration
- Docker network isolation
- File permissions
- Secret management
- Git repository security

## Test Results

All test executions are logged to:
- **Results:** `.claude/tests/TEST_RESULTS.md`
- **Logs:** `.claude/tests/test-run-[timestamp].log`

## Cross-Platform Compatibility

### Bash Scripts (Linux/macOS/WSL)
All test scripts are written in Bash and work natively on:
- ✅ Linux (Ubuntu, Debian, RHEL, etc.)
- ✅ macOS (any version with Bash)
- ✅ Windows via WSL (Windows Subsystem for Linux)
- ✅ Windows via Git Bash (included with Git for Windows)

### Python Scripts (All Platforms)
Python validation scripts work on all platforms:
- ✅ Windows (Python 3.8+)
- ✅ Linux (Python 3.8+)
- ✅ macOS (Python 3.8+)

### Path Compatibility
All Python scripts use `os.path.join()` for cross-platform path handling:
```python
# Works on Windows, Linux, macOS
base_path = os.path.join(".claude", "skills", "pod-research")
```

### Shell Script Compatibility

**Line Endings:**
- Scripts use LF (Unix) line endings
- Git should be configured to handle line endings automatically
- On Windows, ensure Git config: `git config --global core.autocrlf false`

**Command Compatibility:**
| Command | Linux | macOS | Windows (WSL) | Windows (Git Bash) |
|---------|-------|-------|---------------|-------------------|
| `bash` | ✅ | ✅ | ✅ | ✅ |
| `python3` | ✅ | ✅ | ✅ | Use `python` |
| `docker` | ✅ | ✅ | ✅ | ✅ |
| `jq` | ✅ | ✅ | ✅ | ✅ |
| `curl` | ✅ | ✅ | ✅ | ✅ |

## Prerequisites

### Required Software
- **Bash:** 4.0+ (Linux/macOS/WSL) or Git Bash (Windows)
- **Python:** 3.8 or higher
- **Docker:** For MCP server tests
- **jq:** JSON processor (install via package manager)

### Installing jq

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install jq
```

**macOS:**
```bash
brew install jq
```

**Windows (WSL):**
```bash
sudo apt-get install jq
```

**Windows (Git Bash):**
Download from https://stedolan.github.io/jq/download/

### Optional Dependencies
- **bc:** For floating-point calculations in benchmarks
  - Linux: `sudo apt-get install bc`
  - macOS: Pre-installed
  - WSL: `sudo apt-get install bc`

## Running Tests

### Full Test Suite
```bash
# Execute all tests (takes 5-15 minutes)
bash .claude/tests/run-all-tests.sh
```

### Individual Test Categories
```bash
# Component tests only (~2 minutes)
bash .claude/tests/test-skills.sh
bash .claude/tests/test-mcps.sh
bash .claude/tests/test-workflows.sh

# Integration tests (~3 minutes)
bash .claude/tests/test-end-to-end.sh

# Performance benchmarks (~5 minutes)
bash .claude/tests/benchmark-performance.sh

# Security audit (~1 minute)
bash .claude/tests/audit-security.sh
```

### Continuous Integration

For automated testing in CI/CD pipelines:

```bash
# Exit on first failure
set -e

# Run tests
bash .claude/tests/run-all-tests.sh

# Check exit code
if [ $? -eq 0 ]; then
    echo "All tests passed"
else
    echo "Tests failed"
    exit 1
fi
```

## Interpreting Results

### Pass Criteria
- ✅ **PASSED:** Test met all requirements
- ⚠️ **WARNING:** Test passed with minor issues
- ❌ **FAILED:** Test did not meet requirements
- ⬜ **SKIPPED:** Test not applicable or dependency missing

### Exit Codes
- `0` - All tests passed
- `1` - One or more tests failed
- `2` - Critical error (e.g., Docker not running)

### Common Issues

**Issue: Docker not running**
```
Solution: Start Docker Desktop or Docker daemon
```

**Issue: Python scripts fail**
```
Check Python version: python3 --version (need 3.8+)
Install dependencies: pip3 install -r requirements.txt
```

**Issue: Permission denied on Linux**
```bash
Solution: Make scripts executable
chmod +x .claude/tests/*.sh
```

**Issue: jq command not found**
```
Solution: Install jq (see Prerequisites above)
```

**Issue: Line ending errors on Windows**
```
Solution: Convert line endings
dos2unix .claude/tests/*.sh
```

## Test Development

### Adding New Tests

1. **Choose appropriate test file** based on category
2. **Follow existing pattern:**
   ```bash
   info "Test description..."
   RESULT=$(command_here)
   
   if [ "$RESULT" meets criteria ]; then
       success "Test passed"
   else
       error "Test failed"
   fi
   ```

3. **Update TEST_RESULTS.md** template with new test

### Best Practices
- Use `set -e` to fail fast on errors
- Provide clear success/error messages
- Clean up temporary files
- Document expected vs actual results
- Include severity levels for failures

## Troubleshooting

### Debug Mode

Run scripts with debug output:
```bash
bash -x .claude/tests/test-skills.sh
```

### Verbose Logging

Check detailed logs:
```bash
tail -f .claude/tests/test-run-*.log
```

### Manual Verification

Test individual components:
```bash
# Test single skill
python3 .claude/skills/pod-research/scripts/validate.py "test" 20000 60

# Test Docker service
curl http://127.0.0.1:6333/health

# Test JSON syntax
jq '.' .mcp.json
```

## Performance Expectations

| Test Suite | Duration | Token Usage |
|------------|----------|-------------|
| Component Tests | 2-3 min | Minimal |
| Integration Tests | 3-5 min | ~5K tokens |
| E2E Tests | 5-8 min | ~10K tokens |
| Performance Benchmarks | 5-10 min | ~15K tokens |
| Security Audit | 1-2 min | None |
| **Full Suite** | **15-25 min** | **~30K tokens** |

## Support

For issues or questions:
1. Check [`INTEGRATION_TESTS.md`](../../INTEGRATION_TESTS.md) for detailed test documentation
2. Review [`SETUP_GUIDE_ARCHITECTURE.md`](../../SETUP_GUIDE_ARCHITECTURE.md) for system architecture
3. Consult [`CLAUDE_CODE_2.0_POD_BUSINESS_SETUP_GUIDE.md`](../../CLAUDE_CODE_2.0_POD_BUSINESS_SETUP_GUIDE.md) for setup guidance

## Version History

- **1.0** (2025-12-07) - Initial test suite release
  - 7 test categories
  - 9 test execution scripts
  - Cross-platform compatibility
  - Comprehensive documentation

---

**Maintained by:** POD Automation Team  
**Last Updated:** 2025-12-07  
**Test Suite Version:** 1.0