#!/bin/bash

###############################################################################
# POD Automation - Master Test Runner
# Executes all integration tests and generates comprehensive report
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Log file
LOG_FILE=".claude/tests/test-run-$(date +%Y%m%d-%H%M%S).log"
RESULTS_FILE=".claude/tests/TEST_RESULTS.md"

# Helper functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_PASSED++))
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_SKIPPED++))
}

separator() {
    echo "================================================================" | tee -a "$LOG_FILE"
}

###############################################################################
# Main Test Execution
###############################################################################

echo ""
separator
log "POD Automation Integration Tests"
log "Started: $(date)"
separator
echo ""

# Create results directory if it doesn't exist
mkdir -p .claude/tests

# Initialize results file
cat > "$RESULTS_FILE" << 'EOF'
# Integration Test Results

**Date:** $(date)
**Tester:** Automated Test Suite
**Environment:** $(uname -s)

## Test Execution Summary

EOF

###############################################################################
# Category 1: Component Tests
###############################################################################

log "Category 1: Component-Level Tests"
echo ""

# Test MCPs
if [ -f ".claude/tests/test-mcps.sh" ]; then
    log "Running MCP tests..."
    if bash .claude/tests/test-mcps.sh >> "$LOG_FILE" 2>&1; then
        success "MCP tests completed"
    else
        error "MCP tests failed"
    fi
else
    warning "MCP test script not found - skipping"
fi

# Test Skills
if [ -f ".claude/tests/test-skills.sh" ]; then
    log "Running Skills tests..."
    if bash .claude/tests/test-skills.sh >> "$LOG_FILE" 2>&1; then
        success "Skills tests completed"
    else
        error "Skills tests failed"
    fi
else
    warning "Skills test script not found - skipping"
fi

# Test Workflows
if [ -f ".claude/tests/test-workflows.sh" ]; then
    log "Running Workflow tests..."
    if bash .claude/tests/test-workflows.sh >> "$LOG_FILE" 2>&1; then
        success "Workflow tests completed"
    else
        error "Workflow tests failed"
    fi
else
    warning "Workflow test script not found - skipping"
fi

echo ""

###############################################################################
# Category 2: Integration Tests
###############################################################################

log "Category 2: Integration Tests"
echo ""

if [ -f ".claude/tests/test-end-to-end.sh" ]; then
    log "Running end-to-end tests..."
    if bash .claude/tests/test-end-to-end.sh >> "$LOG_FILE" 2>&1; then
        success "End-to-end tests completed"
    else
        error "End-to-end tests failed"
    fi
else
    warning "End-to-end test script not found - skipping"
fi

echo ""

###############################################################################
# Category 3: Performance Benchmarks
###############################################################################

log "Category 3: Performance Benchmarks"
echo ""

if [ -f ".claude/tests/benchmark-performance.sh" ]; then
    log "Running performance benchmarks..."
    if bash .claude/tests/benchmark-performance.sh >> "$LOG_FILE" 2>&1; then
        success "Performance benchmarks completed"
    else
        error "Performance benchmarks failed"
    fi
else
    warning "Performance benchmark script not found - skipping"
fi

echo ""

###############################################################################
# Category 4: Security Audit
###############################################################################

log "Category 4: Security Audit"
echo ""

if [ -f ".claude/tests/audit-security.sh" ]; then
    log "Running security audit..."
    if bash .claude/tests/audit-security.sh >> "$LOG_FILE" 2>&1; then
        success "Security audit completed"
    else
        error "Security audit failed"
    fi
else
    warning "Security audit script not found - skipping"
fi

echo ""

###############################################################################
# Results Summary
###############################################################################

separator
log "Test Execution Complete"
separator
echo ""

log "Results Summary:"
success "Passed: $TESTS_PASSED"
error "Failed: $TESTS_FAILED"
warning "Skipped: $TESTS_SKIPPED"

TOTAL=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
if [ $TOTAL -gt 0 ]; then
    PASS_RATE=$((TESTS_PASSED * 100 / TOTAL))
    log "Pass Rate: ${PASS_RATE}%"
fi

echo ""
log "Detailed log saved to: $LOG_FILE"
log "Results documented in: $RESULTS_FILE"
echo ""

separator
log "Completed: $(date)"
separator

# Exit with error if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0