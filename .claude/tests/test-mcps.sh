#!/bin/bash

###############################################################################
# POD Automation - MCP Server Testing
# Tests MCP servers and Docker services
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
# Test: .mcp.json Configuration
###############################################################################

echo ""
echo "=== Testing MCP Configuration ==="
echo ""

# Test 1: .mcp.json exists and is valid JSON
info "Test 1: Validating .mcp.json..."
if [ -f ".mcp.json" ]; then
    if jq '.' .mcp.json >/dev/null 2>&1; then
        success ".mcp.json is valid JSON"
    else
        error ".mcp.json is invalid JSON"
    fi
else
    error ".mcp.json not found"
fi

# Test 2: Required MCP servers configured
info "Test 2: Checking configured MCP servers..."
if [ -f ".mcp.json" ]; then
    # Check for filesystem server
    if jq -e '.mcpServers | has("filesystem")' .mcp.json >/dev/null 2>&1; then
        success "Filesystem MCP server configured"
    else
        error "Filesystem MCP server not configured"
    fi
    
    # Check for brave-search (optional)
    if jq -e '.mcpServers | has("brave-search")' .mcp.json >/dev/null 2>&1; then
        success "Brave-search MCP server configured"
    else
        info "Brave-search MCP server not configured (optional)"
    fi
fi

# Test 3: Security compliance settings
info "Test 3: Validating security configuration..."
if [ -f ".mcp.json" ]; then
    if jq -e '.security_compliance' .mcp.json >/dev/null 2>&1; then
        AUTH_METHOD=$(jq -r '.security_compliance.auth_method' .mcp.json 2>/dev/null || echo "none")
        if [ "$AUTH_METHOD" == "oauth_only" ]; then
            success "OAuth-only authentication configured"
        else
            error "OAuth-only authentication not configured"
        fi
        
        STATIC_KEYS=$(jq -r '.security_compliance.static_keys' .mcp.json 2>/dev/null || echo "true")
        if [ "$STATIC_KEYS" == "false" ]; then
            success "Static keys disabled"
        else
            error "Static keys still enabled"
        fi
    else
        error "Security compliance settings not found"
    fi
fi

###############################################################################
# Test: Docker Services
###############################################################################

echo ""
echo "=== Testing Docker Services ==="
echo ""

# Test 1: Docker is running
info "Test 1: Checking Docker daemon..."
if docker info >/dev/null 2>&1; then
    success "Docker daemon is running"
else
    error "Docker daemon not running or not accessible"
    echo ""
    echo "Skipping remaining Docker tests..."
    exit 1
fi

# Test 2: Qdrant container
info "Test 2: Checking Qdrant vector database..."
if docker ps --format '{{.Names}}' | grep -q "qdrant-pod"; then
    success "Qdrant container is running"
    
    # Test health endpoint
    if curl -s http://127.0.0.1:6333/health | grep -q "ok"; then
        success "Qdrant health check passed"
    else
        error "Qdrant health check failed"
    fi
else
    error "Qdrant container not running"
fi

# Test 3: Neo4j container
info "Test 3: Checking Neo4j graph database..."
if docker ps --format '{{.Names}}' | grep -q "neo4j-pod"; then
    success "Neo4j container is running"
    
    # Test HTTP endpoint
    if curl -s http://127.0.0.1:7474 >/dev/null 2>&1; then
        success "Neo4j HTTP endpoint accessible"
    else
        error "Neo4j HTTP endpoint not accessible"
    fi
else
    error "Neo4j container not running"
fi

# Test 4: Port bindings (localhost only)
info "Test 4: Verifying localhost-only port bindings..."
QDRANT_PORTS=$(docker inspect qdrant-pod 2>/dev/null | jq -r '.[0].NetworkSettings.Ports | to_entries[] | .value[0].HostIp' || echo "error")

if [ "$QDRANT_PORTS" != "error" ]; then
    if echo "$QDRANT_PORTS" | grep -qv "127.0.0.1"; then
        error "Qdrant has non-localhost bindings"
    else
        success "Qdrant ports bound to localhost only"
    fi
else
    info "Could not inspect Qdrant port bindings"
fi

###############################################################################
# Test: Filesystem MCP
###############################################################################

echo ""
echo "=== Testing Filesystem MCP ==="
echo ""

# Test 1: Write test file
info "Test 1: Creating test file via filesystem..."
TEST_FILE=".claude/data/mcp-test-$(date +%s).json"
mkdir -p .claude/data
echo '{"test": "data", "timestamp": "'$(date -Iseconds)'"}' > "$TEST_FILE"

if [ -f "$TEST_FILE" ]; then
    success "Test file created successfully"
    
    # Verify content
    if grep -q "test.*data" "$TEST_FILE"; then
        success "Test file contains expected data"
    else
        error "Test file content invalid"
    fi
    
    # Cleanup
    rm -f "$TEST_FILE"
else
    error "Test file creation failed"
fi

# Test 2: Directory access
info "Test 2: Validating directory structure..."
REQUIRED_DIRS=(".claude" ".claude/skills" ".claude/memories" ".claude/data")

for DIR in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        success "Directory exists: $DIR"
    else
        error "Directory missing: $DIR"
    fi
done

###############################################################################
# Test: MCP Health Check Script
###############################################################################

echo ""
echo "=== Testing MCP Health Check Script ==="
echo ""

if [ -f "mcp-health-check.sh" ]; then
    info "Running mcp-health-check.sh..."
    if bash mcp-health-check.sh >/dev/null 2>&1; then
        success "MCP health check script executed successfully"
    else
        error "MCP health check script failed"
    fi
else
    error "mcp-health-check.sh not found"
fi

###############################################################################
# Test: Docker Compose Configuration
###############################################################################

echo ""
echo "=== Testing Docker Compose Configuration ==="
echo ""

if [ -f "docker-compose.yml" ]; then
    # Validate YAML syntax
    if docker-compose config >/dev/null 2>&1; then
        success "docker-compose.yml is valid"
    else
        error "docker-compose.yml has syntax errors"
    fi
    
    # Check for required services
    if grep -q "qdrant:" docker-compose.yml; then
        success "Qdrant service defined in docker-compose.yml"
    else
        error "Qdrant service not found in docker-compose.yml"
    fi
    
    if grep -q "neo4j:" docker-compose.yml; then
        success "Neo4j service defined in docker-compose.yml"
    else
        error "Neo4j service not found in docker-compose.yml"
    fi
else
    error "docker-compose.yml not found"
fi

###############################################################################
# Results Summary
###############################################################################

echo ""
echo "==================================="
echo "MCP Test Summary"
echo "==================================="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0