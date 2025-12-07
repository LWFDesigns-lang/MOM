#!/bin/bash

###############################################################################
# POD Automation - Skills Testing
# Tests each skill independently for correct functionality
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
# Test: pod-research skill
###############################################################################

echo ""
echo "=== Testing pod-research skill ==="
echo ""

# Test 1: GO decision (good niche)
info "Test 1: Validation with GO decision..."
RESULT=$(python3 .claude/skills/pod-research/scripts/validate.py "indoor plant care" 18500 62 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    DECISION=$(echo "$RESULT" | jq -r '.decision' 2>/dev/null || echo "INVALID")
    if [ "$DECISION" == "GO" ]; then
        success "GO decision returned correctly"
    else
        error "Expected GO decision, got: $DECISION"
    fi
    
    CONFIDENCE=$(echo "$RESULT" | jq -r '.confidence' 2>/dev/null || echo "0")
    if (( $(echo "$CONFIDENCE >= 0.60" | bc -l) )); then
        success "Confidence score acceptable: $CONFIDENCE"
    else
        error "Confidence too low: $CONFIDENCE"
    fi
else
    error "validate.py execution failed"
fi

# Test 2: SKIP decision (oversaturated)
info "Test 2: Validation with SKIP decision..."
RESULT=$(python3 .claude/skills/pod-research/scripts/validate.py "funny cat" 95000 88 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    DECISION=$(echo "$RESULT" | jq -r '.decision' 2>/dev/null || echo "INVALID")
    if [ "$DECISION" == "SKIP" ]; then
        success "SKIP decision returned correctly"
    else
        error "Expected SKIP decision, got: $DECISION"
    fi
else
    error "validate.py execution failed for SKIP test"
fi

# Test 3: JSON output validity
info "Test 3: Validating JSON output structure..."
RESULT=$(python3 .claude/skills/pod-research/scripts/validate.py "test niche" 20000 60 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    # Check required fields
    HAS_DECISION=$(echo "$RESULT" | jq 'has("decision")' 2>/dev/null || echo "false")
    HAS_CONFIDENCE=$(echo "$RESULT" | jq 'has("confidence")' 2>/dev/null || echo "false")
    HAS_REASONING=$(echo "$RESULT" | jq 'has("reasoning")' 2>/dev/null || echo "false")
    
    if [ "$HAS_DECISION" == "true" ] && [ "$HAS_CONFIDENCE" == "true" ] && [ "$HAS_REASONING" == "true" ]; then
        success "JSON structure valid with all required fields"
    else
        error "JSON missing required fields"
    fi
else
    error "validate.py JSON validation failed"
fi

###############################################################################
# Test: pod-pricing skill
###############################################################################

echo ""
echo "=== Testing pod-pricing skill ==="
echo ""

# Test 1: Standard tee pricing
info "Test 1: Standard tee pricing calculation..."
RESULT=$(python3 .claude/skills/pod-pricing/scripts/pricing.py "tee_standard" 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    PRICE=$(echo "$RESULT" | jq -r '.recommended_price' 2>/dev/null || echo "0")
    
    # Check if price is in expected range ($30-$40)
    if (( $(echo "$PRICE >= 30 && $PRICE <= 40" | bc -l) )); then
        success "Standard tee price in expected range: \$$PRICE"
    else
        error "Price out of range: \$$PRICE (expected $30-$40)"
    fi
    
    # Check margin
    MARGIN=$(echo "$RESULT" | jq -r '.actual_margin' 2>/dev/null || echo "0")
    if (( $(echo "$MARGIN >= 0.50" | bc -l) )); then
        success "Margin acceptable: $(echo "$MARGIN * 100" | bc)%"
    else
        error "Margin too low: $(echo "$MARGIN * 100" | bc)%"
    fi
else
    error "pricing.py execution failed for standard tee"
fi

# Test 2: Hoodie pricing
info "Test 2: Hoodie pricing calculation..."
RESULT=$(python3 .claude/skills/pod-pricing/scripts/pricing.py "hoodie_standard" 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    PRICE=$(echo "$RESULT" | jq -r '.recommended_price' 2>/dev/null || echo "0")
    
    # Check if price is in expected range ($50-$60)
    if (( $(echo "$PRICE >= 50 && $PRICE <= 60" | bc -l) )); then
        success "Hoodie price in expected range: \$$PRICE"
    else
        error "Price out of range: \$$PRICE (expected $50-$60)"
    fi
else
    error "pricing.py execution failed for hoodie"
fi

# Test 3: JSON structure
info "Test 3: Validating pricing JSON structure..."
RESULT=$(python3 .claude/skills/pod-pricing/scripts/pricing.py "tee_standard" 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    HAS_FIELDS=$(echo "$RESULT" | jq 'has("product_type") and has("recommended_price") and has("actual_margin")' 2>/dev/null || echo "false")
    
    if [ "$HAS_FIELDS" == "true" ]; then
        success "Pricing JSON structure valid"
    else
        error "Pricing JSON missing required fields"
    fi
else
    error "pricing.py JSON validation failed"
fi

###############################################################################
# Test: pod-listing-seo skill
###############################################################################

echo ""
echo "=== Testing pod-listing-seo skill ==="
echo ""

# Test 1: SEO validation
info "Test 1: SEO listing validation..."
TITLE="Indoor Plant Care Tee - Organic Cotton Gift"
KEYWORDS='["plant lover","organic cotton","plant care"]'
DESCRIPTION="Premium organic cotton tee for plant lovers. Perfect gift for indoor gardening enthusiasts."

RESULT=$(python3 .claude/skills/pod-listing-seo/scripts/validate_seo.py "$TITLE" "$KEYWORDS" "$DESCRIPTION" 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    SEO_SCORE=$(echo "$RESULT" | jq -r '.seo_score' 2>/dev/null || echo "0")
    
    if (( $(echo "$SEO_SCORE >= 60" | bc -l) )); then
        success "SEO score acceptable: $SEO_SCORE"
    else
        error "SEO score too low: $SEO_SCORE"
    fi
    
    # Check for recommendations
    HAS_RECOMMENDATIONS=$(echo "$RESULT" | jq 'has("recommendations")' 2>/dev/null || echo "false")
    if [ "$HAS_RECOMMENDATIONS" == "true" ]; then
        success "SEO recommendations provided"
    else
        error "No SEO recommendations in output"
    fi
else
    error "validate_seo.py execution failed"
fi

###############################################################################
# Test: SKILL.md files exist
###############################################################################

echo ""
echo "=== Testing SKILL.md files ==="
echo ""

SKILLS=("pod-research" "pod-design-review" "pod-pricing" "pod-listing-seo" "memory-manager")

for SKILL in "${SKILLS[@]}"; do
    if [ -f ".claude/skills/$SKILL/SKILL.md" ]; then
        # Check file is not empty and has minimum content
        LINE_COUNT=$(wc -l < ".claude/skills/$SKILL/SKILL.md")
        if [ "$LINE_COUNT" -ge 50 ]; then
            success "$SKILL: SKILL.md exists with $LINE_COUNT lines"
        else
            error "$SKILL: SKILL.md too short ($LINE_COUNT lines)"
        fi
    else
        error "$SKILL: SKILL.md not found"
    fi
done

###############################################################################
# Test: Skill triggers
###############################################################################

echo ""
echo "=== Testing Skill Trigger Phrases ==="
echo ""

# Validate trigger phrases are defined in SKILL.md files
for SKILL in "${SKILLS[@]}"; do
    if [ -f ".claude/skills/$SKILL/SKILL.md" ]; then
        if grep -q "trigger.*phrase" ".claude/skills/$SKILL/SKILL.md" 2>/dev/null; then
            success "$SKILL: Trigger phrases defined"
        else
            error "$SKILL: No trigger phrases found in SKILL.md"
        fi
    fi
done

###############################################################################
# Results Summary
###############################################################################

echo ""
echo "==================================="
echo "Skills Test Summary"
echo "==================================="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0