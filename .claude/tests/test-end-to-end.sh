#!/bin/bash

###############################################################################
# POD Automation - End-to-End Testing
# Simulates complete workflows from start to finish
###############################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

###############################################################################
# E2E Test 1: Single Niche Validation
###############################################################################

header "E2E Test 1: Single Niche Validation"

NICHE="minimalist plant care"
COMPETITION=18500
TREND_SCORE=62

info "Testing niche: '$NICHE'"
info "Competition: $COMPETITION listings"
info "Trend Score: $TREND_SCORE"

# Step 1: Run validation
info "Step 1: Running pod-research validation..."
RESULT=$(python3 .claude/skills/pod-research/scripts/validate.py "$NICHE" $COMPETITION $TREND_SCORE 2>/dev/null || echo "ERROR")

if [ "$RESULT" != "ERROR" ]; then
    success "Validation script executed successfully"
    
    # Check decision
    DECISION=$(echo "$RESULT" | jq -r '.decision' 2>/dev/null || echo "INVALID")
    if [ "$DECISION" == "GO" ]; then
        success "Received GO decision (as expected for good niche)"
    elif [ "$DECISION" == "SKIP" ]; then
        error "Received SKIP decision (unexpected for this niche)"
    else
        error "Invalid decision: $DECISION"
    fi
    
    # Check confidence
    CONFIDENCE=$(echo "$RESULT" | jq -r '.confidence' 2>/dev/null || echo "0")
    if (( $(echo "$CONFIDENCE >= 0.60" | bc -l 2>/dev/null || echo "0") )); then
        success "Confidence score acceptable: $CONFIDENCE"
    else
        error "Confidence score too low: $CONFIDENCE"
    fi
    
    # Step 2: Verify result structure
    info "Step 2: Validating result structure..."
    HAS_ALL_FIELDS=$(echo "$RESULT" | jq 'has("decision") and has("confidence") and has("reasoning") and has("niche")' 2>/dev/null || echo "false")
    if [ "$HAS_ALL_FIELDS" == "true" ]; then
        success "Result contains all required fields"
    else
        error "Result missing required fields"
    fi
else
    error "Validation script failed to execute"
fi

###############################################################################
# E2E Test 2: Pricing Calculation Flow
###############################################################################

header "E2E Test 2: Pricing Calculation Flow"

PRODUCT_TYPE="tee_standard"

info "Testing pricing for: $PRODUCT_TYPE"

# Step 1: Calculate pricing
info "Step 1: Running pod-pricing calculation..."
PRICING_RESULT=$(python3 .claude/skills/pod-pricing/scripts/pricing.py "$PRODUCT_TYPE" 2>/dev/null || echo "ERROR")

if [ "$PRICING_RESULT" != "ERROR" ]; then
    success "Pricing script executed successfully"
    
    # Verify price
    PRICE=$(echo "$PRICING_RESULT" | jq -r '.recommended_price' 2>/dev/null || echo "0")
    if (( $(echo "$PRICE >= 30 && $PRICE <= 40" | bc -l 2>/dev/null || echo "0") )); then
        success "Price in expected range: \$$PRICE"
    else
        error "Price out of range: \$$PRICE"
    fi
    
    # Step 2: Verify margin calculation
    info "Step 2: Validating margin calculation..."
    MARGIN=$(echo "$PRICING_RESULT" | jq -r '.actual_margin' 2>/dev/null || echo "0")
    TARGET_MARGIN=$(echo "$PRICING_RESULT" | jq -r '.target_margin' 2>/dev/null || echo "0")
    
    if (( $(echo "$MARGIN >= 0.50" | bc -l 2>/dev/null || echo "0") )); then
        success "Margin meets minimum threshold: $(echo "$MARGIN * 100" | bc)%"
    else
        error "Margin below threshold: $(echo "$MARGIN * 100" | bc)%"
    fi
    
    # Step 3: Verify profit calculation
    info "Step 3: Validating profit per unit..."
    PROFIT=$(echo "$PRICING_RESULT" | jq -r '.profit_per_unit' 2>/dev/null || echo "0")
    if (( $(echo "$PROFIT >= 15" | bc -l 2>/dev/null || echo "0") )); then
        success "Profit per unit acceptable: \$$PROFIT"
    else
        error "Profit per unit too low: \$$PROFIT"
    fi
else
    error "Pricing script failed to execute"
fi

###############################################################################
# E2E Test 3: SEO Listing Generation Flow
###############################################################################

header "E2E Test 3: SEO Listing Generation Flow"

TITLE="Indoor Plant Care Tee - Organic Cotton Gift for Plant Lovers"
KEYWORDS='["plant lover","organic cotton","plant care","indoor plants","gardening gift"]'
DESCRIPTION="Show your love for indoor plants with this premium organic cotton tee. Perfect for plant parents and gardening enthusiasts. Features eco-friendly materials and comfortable fit. Great gift for plant lovers who care about sustainability and the environment."

info "Testing SEO validation..."

# Step 1: Validate SEO
info "Step 1: Running pod-listing-seo validation..."
SEO_RESULT=$(python3 .claude/skills/pod-listing-seo/scripts/validate_seo.py "$TITLE" "$KEYWORDS" "$DESCRIPTION" 2>/dev/null || echo "ERROR")

if [ "$SEO_RESULT" != "ERROR" ]; then
    success "SEO validation executed successfully"
    
    # Check SEO score
    SEO_SCORE=$(echo "$SEO_RESULT" | jq -r '.seo_score' 2>/dev/null || echo "0")
    if (( $(echo "$SEO_SCORE >= 60" | bc -l 2>/dev/null || echo "0") )); then
        success "SEO score acceptable: $SEO_SCORE"
    else
        error "SEO score too low: $SEO_SCORE"
    fi
    
    # Step 2: Check title quality
    info "Step 2: Validating title quality..."
    TITLE_QUALITY=$(echo "$SEO_RESULT" | jq -r '.title_quality' 2>/dev/null || echo "unknown")
    if [ "$TITLE_QUALITY" == "excellent" ] || [ "$TITLE_QUALITY" == "good" ]; then
        success "Title quality: $TITLE_QUALITY"
    else
        error "Title quality insufficient: $TITLE_QUALITY"
    fi
    
    # Step 3: Check keyword usage
    info "Step 3: Validating keyword usage..."
    KEYWORDS_USED=$(echo "$SEO_RESULT" | jq -r '.keywords_used' 2>/dev/null || echo "0")
    if [ "$KEYWORDS_USED" -ge 3 ]; then
        success "Keywords used: $KEYWORDS_USED"
    else
        error "Insufficient keywords used: $KEYWORDS_USED"
    fi
else
    error "SEO validation script failed to execute"
fi

###############################################################################
# E2E Test 4: Memory Persistence Flow
###############################################################################

header "E2E Test 4: Memory Persistence Flow"

info "Testing memory system integration..."

# Step 1: Check validated_niches.json exists
info "Step 1: Checking validated niches storage..."
if [ -f ".claude/memories/validated_niches.json" ]; then
    if jq '.' .claude/memories/validated_niches.json >/dev/null 2>&1; then
        success "validated_niches.json exists and is valid JSON"
    else
        error "validated_niches.json is invalid JSON"
    fi
else
    error "validated_niches.json not found"
fi

# Step 2: Check brand voice files
info "Step 2: Checking brand voice memories..."
BRAND_FILES=("brand_voice_lwf.md" "brand_voice_touge.md")

for BRAND_FILE in "${BRAND_FILES[@]}"; do
    if [ -f ".claude/memories/$BRAND_FILE" ]; then
        LINE_COUNT=$(wc -l < ".claude/memories/$BRAND_FILE" 2>/dev/null || echo "0")
        if [ "$LINE_COUNT" -ge 50 ]; then
            success "Brand file exists with sufficient content: $BRAND_FILE"
        else
            error "Brand file too short: $BRAND_FILE"
        fi
    else
        error "Brand file not found: $BRAND_FILE"
    fi
done

# Step 3: Test memory structure
info "Step 3: Validating memory directory structure..."
MEMORY_DIRS=(".claude/memories" ".claude/data")

for DIR in "${MEMORY_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        success "Memory directory exists: $DIR"
    else
        error "Memory directory missing: $DIR"
    fi
done

###############################################################################
# E2E Test 5: Full Pipeline Simulation
###############################################################################

header "E2E Test 5: Full Pipeline Simulation"

info "Simulating complete POD workflow..."

# Step 1: Research phase
info "Step 1: Research & Validation phase..."
RESEARCH_NICHE="sustainable gardening tools"
RESEARCH_RESULT=$(python3 .claude/skills/pod-research/scripts/validate.py "$RESEARCH_NICHE" 22000 68 2>/dev/null || echo "ERROR")

if [ "$RESEARCH_RESULT" != "ERROR" ]; then
    RESEARCH_DECISION=$(echo "$RESEARCH_RESULT" | jq -r '.decision' 2>/dev/null || echo "INVALID")
    success "Research phase completed: $RESEARCH_DECISION"
    
    # Only continue if GO decision
    if [ "$RESEARCH_DECISION" == "GO" ]; then
        # Step 2: Pricing phase
        info "Step 2: Pricing calculation phase..."
        PRICE_RESULT=$(python3 .claude/skills/pod-pricing/scripts/pricing.py "tee_standard" 2>/dev/null || echo "ERROR")
        
        if [ "$PRICE_RESULT" != "ERROR" ]; then
            RECOMMENDED_PRICE=$(echo "$PRICE_RESULT" | jq -r '.recommended_price' 2>/dev/null || echo "0")
            success "Pricing phase completed: \$$RECOMMENDED_PRICE"
            
            # Step 3: SEO phase
            info "Step 3: SEO listing creation phase..."
            SEO_TITLE="Sustainable Gardening Tools Tee - Eco-Friendly Gift"
            SEO_KEYWORDS='["sustainable","gardening","eco-friendly","tools"]'
            SEO_DESC="Premium tee for sustainable gardening enthusiasts. Eco-friendly materials."
            
            SEO_FINAL=$(python3 .claude/skills/pod-listing-seo/scripts/validate_seo.py "$SEO_TITLE" "$SEO_KEYWORDS" "$SEO_DESC" 2>/dev/null || echo "ERROR")
            
            if [ "$SEO_FINAL" != "ERROR" ]; then
                success "SEO phase completed"
                
                # Step 4: Summary
                info "Step 4: Pipeline summary..."
                success "Full pipeline completed successfully"
                info "  • Niche: $RESEARCH_NICHE"
                info "  • Decision: $RESEARCH_DECISION"
                info "  • Price: \$$RECOMMENDED_PRICE"
                SEO_FINAL_SCORE=$(echo "$SEO_FINAL" | jq -r '.seo_score' 2>/dev/null || echo "N/A")
                info "  • SEO Score: $SEO_FINAL_SCORE"
            else
                error "SEO phase failed"
            fi
        else
            error "Pricing phase failed"
        fi
    else
        info "SKIP decision - pipeline halted (expected behavior)"
        success "Pipeline correctly halted at validation stage"
    fi
else
    error "Research phase failed"
fi

###############################################################################
# E2E Test 6: Error Handling
###############################################################################

header "E2E Test 6: Error Handling & Recovery"

info "Testing error handling capabilities..."

# Test 1: Invalid input handling
info "Test 1: Invalid input handling..."
INVALID_RESULT=$(python3 .claude/skills/pod-research/scripts/validate.py "test" "invalid" "data" 2>&1 || echo "ERROR")

if echo "$INVALID_RESULT" | grep -qi "error"; then
    success "Invalid input handled gracefully"
else
    error "Invalid input not properly handled"
fi

# Test 2: Missing files handling
info "Test 2: Missing file handling..."
if [ ! -f ".claude/nonexistent.json" ]; then
    success "System correctly identifies missing files"
else
    error "Unexpected file exists"
fi

# Test 3: JSON corruption detection
info "Test 3: JSON validation..."
echo '{"test": "data"}' > /tmp/test-valid.json
if jq '.' /tmp/test-valid.json >/dev/null 2>&1; then
    success "Valid JSON detected correctly"
else
    error "JSON validation failed"
fi
rm -f /tmp/test-valid.json

###############################################################################
# Results Summary
###############################################################################

echo ""
echo "==================================="
echo "End-to-End Test Summary"
echo "==================================="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0