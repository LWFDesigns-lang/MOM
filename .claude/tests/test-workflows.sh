#!/bin/bash

###############################################################################
# POD Automation - Workflow Testing
# Tests workflow configurations and automation
###############################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

success() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

error() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

###############################################################################
# Test: Workflow Definitions
###############################################################################

echo ""
echo "=== Testing Workflow Definitions ==="
echo ""

# Test 1: Workflow files exist
info "Test 1: Checking workflow files..."
WORKFLOW_DIR=".claude/automation/workflows"

if [ -d "$WORKFLOW_DIR" ]; then
    success "Workflow directory exists"
    
    # Check for expected workflow files
    WORKFLOWS=("full_pipeline.yaml" "research_only.yaml" "design_batch.yaml")
    for WORKFLOW in "${WORKFLOWS[@]}"; do
        if [ -f "$WORKFLOW_DIR/$WORKFLOW" ]; then
            success "Workflow file exists: $WORKFLOW"
        else
            error "Workflow file missing: $WORKFLOW"
        fi
    done
else
    error "Workflow directory not found: $WORKFLOW_DIR"
fi

# Test 2: Validate YAML syntax
info "Test 2: Validating YAML syntax..."
if command -v python3 >/dev/null 2>&1; then
    for WORKFLOW_FILE in "$WORKFLOW_DIR"/*.yaml; do
        if [ -f "$WORKFLOW_FILE" ]; then
            FILENAME=$(basename "$WORKFLOW_FILE")
            if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_FILE'))" 2>/dev/null; then
                success "Valid YAML: $FILENAME"
            else
                error "Invalid YAML: $FILENAME"
            fi
        fi
    done
else
    info "Python3 not available, skipping YAML validation"
fi

###############################################################################
# Test: Subagent Configurations
###############################################################################

echo ""
echo "=== Testing Subagent Configurations ==="
echo ""

# Test 1: Subagent files exist
info "Test 1: Checking subagent files..."
SUBAGENT_DIR=".claude/automation/subagents"

if [ -d "$SUBAGENT_DIR" ]; then
    success "Subagent directory exists"
    
    SUBAGENTS=("research-validator.json" "design-generator.json" "listing-optimizer.json")
    for SUBAGENT in "${SUBAGENTS[@]}"; do
        if [ -f "$SUBAGENT_DIR/$SUBAGENT" ]; then
            # Validate JSON
            if jq '.' "$SUBAGENT_DIR/$SUBAGENT" >/dev/null 2>&1; then
                success "Valid subagent config: $SUBAGENT"
            else
                error "Invalid JSON in: $SUBAGENT"
            fi
        else
            error "Subagent file missing: $SUBAGENT"
        fi
    done
else
    error "Subagent directory not found: $SUBAGENT_DIR"
fi

# Test 2: Required fields in subagent configs
info "Test 2: Validating subagent configuration fields..."
for SUBAGENT_FILE in "$SUBAGENT_DIR"/*.json; do
    if [ -f "$SUBAGENT_FILE" ]; then
        FILENAME=$(basename "$SUBAGENT_FILE")
        
        # Check for required fields
        HAS_NAME=$(jq -e 'has("name")' "$SUBAGENT_FILE" 2>/dev/null && echo "true" || echo "false")
        HAS_PURPOSE=$(jq -e 'has("purpose")' "$SUBAGENT_FILE" 2>/dev/null && echo "true" || echo "false")
        HAS_SKILLS=$(jq -e 'has("skills")' "$SUBAGENT_FILE" 2>/dev/null && echo "true" || echo "false")
        
        if [ "$HAS_NAME" == "true" ] && [ "$HAS_PURPOSE" == "true" ] && [ "$HAS_SKILLS" == "true" ]; then
            success "Required fields present in: $FILENAME"
        else
            error "Missing required fields in: $FILENAME"
        fi
    fi
done

###############################################################################
# Test: Hooks Configuration
###############################################################################

echo ""
echo "=== Testing Hooks Configuration ==="
echo ""

# Test 1: Hooks directory and files
info "Test 1: Checking hooks configuration..."
HOOKS_DIR=".claude/hooks"

if [ -d "$HOOKS_DIR" ]; then
    success "Hooks directory exists"
    
    # Check for hook files
    if [ -f "$HOOKS_DIR/post-skill-complete.json" ]; then
        if jq '.' "$HOOKS_DIR/post-skill-complete.json" >/dev/null 2>&1; then
            success "post-skill-complete.json is valid"
        else
            error "post-skill-complete.json is invalid JSON"
        fi
    else
        error "post-skill-complete.json not found"
    fi
else
    error "Hooks directory not found"
fi

# Test 2: Hook trigger conditions
info "Test 2: Validating hook triggers..."
if [ -f "$HOOKS_DIR/post-skill-complete.json" ]; then
    HAS_TRIGGERS=$(jq -e 'has("triggers")' "$HOOKS_DIR/post-skill-complete.json" 2>/dev/null && echo "true" || echo "false")
    HAS_ACTIONS=$(jq -e 'has("actions")' "$HOOKS_DIR/post-skill-complete.json" 2>/dev/null && echo "true" || echo "false")
    
    if [ "$HAS_TRIGGERS" == "true" ] && [ "$HAS_ACTIONS" == "true" ]; then
        success "Hook has triggers and actions defined"
    else
        error "Hook missing triggers or actions"
    fi
fi

###############################################################################
# Test: Skill Chains
###############################################################################

echo ""
echo "=== Testing Skill Chains ==="
echo ""

# Test 1: Chain definitions exist
info "Test 1: Checking skill chain definitions..."
CHAINS_DIR=".claude/automation/chains"

if [ -d "$CHAINS_DIR" ]; then
    success "Chains directory exists"
    
    # Look for chain files
    CHAIN_COUNT=$(find "$CHAINS_DIR" -name "*.json" -o -name "*.yaml" 2>/dev/null | wc -l)
    if [ "$CHAIN_COUNT" -gt 0 ]; then
        success "Found $CHAIN_COUNT chain definition(s)"
    else
        info "No chain definitions found (optional)"
    fi
else
    info "Chains directory not found (optional)"
fi

###############################################################################
# Test: Fallback Chains
###############################################################################

echo ""
echo "=== Testing Fallback Chains ==="
echo ""

# Test 1: Fallback configuration
info "Test 1: Checking fallback chain configuration..."
FALLBACK_DIR=".claude/automation/fallbacks"

if [ -d "$FALLBACK_DIR" ]; then
    success "Fallback directory exists"
    
    # Check for fallback definitions
    if [ -f "$FALLBACK_DIR/mcp-failure.json" ]; then
        if jq '.' "$FALLBACK_DIR/mcp-failure.json" >/dev/null 2>&1; then
            success "MCP failure fallback configured"
        else
            error "MCP failure fallback JSON invalid"
        fi
    else
        info "MCP failure fallback not configured (optional)"
    fi
else
    info "Fallback directory not found (optional)"
fi

###############################################################################
# Test: Context Management Scripts
###############################################################################

echo ""
echo "=== Testing Context Management Scripts ==="
echo ""

# Test 1: Context manager script
info "Test 1: Checking context-manager.sh..."
if [ -f ".claude/scripts/context-manager.sh" ]; then
    if bash -n .claude/scripts/context-manager.sh 2>/dev/null; then
        success "context-manager.sh syntax valid"
    else
        error "context-manager.sh has syntax errors"
    fi
else
    error "context-manager.sh not found"
fi

# Test 2: Checkpoint manager script
info "Test 2: Checking checkpoint-manager.sh..."
if [ -f ".claude/scripts/checkpoint-manager.sh" ]; then
    if bash -n .claude/scripts/checkpoint-manager.sh 2>/dev/null; then
        success "checkpoint-manager.sh syntax valid"
    else
        error "checkpoint-manager.sh has syntax errors"
    fi
else
    error "checkpoint-manager.sh not found"
fi

###############################################################################
# Results Summary
###############################################################################

echo ""
echo "==================================="
echo "Workflow Test Summary"
echo "==================================="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0