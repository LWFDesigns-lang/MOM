#!/bin/bash

###############################################################################
# POD Automation - Security Audit
# Audits security implementation and compliance
###############################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
CRITICAL_ISSUES=0

success() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

error() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

critical() {
    echo -e "${RED}⚠ CRITICAL:${NC} $1"
    ((CRITICAL_ISSUES++))
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
# Audit 1: API Key Security
###############################################################################

header "Audit 1: API Key Security"

info "Checking for exposed API keys..."

# Check .env file for static keys
if [ -f ".env" ]; then
    info "Checking .env file..."
    
    # Look for potential API keys (excluding VAULT references)
    EXPOSED_KEYS=$(grep -i "key.*=" .env | grep -v "VAULT" | grep -v "EXAMPLE" | grep -v "^#" || true)
    
    if [ -z "$EXPOSED_KEYS" ]; then
        success "No static API keys found in .env"
    else
        critical "Static API keys found in .env:"
        echo "$EXPOSED_KEYS"
    fi
else
    success ".env file not found (using .env.example only)"
fi

# Check .env.example only contains placeholders
if [ -f ".env.example" ]; then
    info "Checking .env.example for placeholders..."
    
    REAL_KEYS=$(grep -i "key.*=" .env.example | grep -v "VAULT" | grep -v "EXAMPLE" | grep -v "your-" | grep -v "xxx" || true)
    
    if [ -z "$REAL_KEYS" ]; then
        success ".env.example contains only placeholders"
    else
        error ".env.example may contain real keys"
    fi
else
    error ".env.example not found"
fi

# Check for keys in code files
info "Scanning code files for hardcoded keys..."
HARDCODED=$(grep -r "api_key\s*=\s*\"[^V]" .claude --include="*.py" --include="*.sh" 2>/dev/null || true)

if [ -z "$HARDCODED" ]; then
    success "No hardcoded API keys in scripts"
else
    critical "Hardcoded API keys detected in scripts"
fi

###############################################################################
# Audit 2: MCP Security Configuration
###############################################################################

header "Audit 2: MCP Security Configuration"

info "Checking MCP security settings..."

if [ -f ".mcp.json" ]; then
    # Check authentication method
    AUTH_METHOD=$(jq -r '.security_compliance.auth_method' .mcp.json 2>/dev/null || echo "none")
    
    if [ "$AUTH_METHOD" == "oauth_only" ]; then
        success "OAuth-only authentication configured"
    else
        critical "OAuth-only authentication NOT configured (found: $AUTH_METHOD)"
    fi
    
    # Check static keys disabled
    STATIC_KEYS=$(jq -r '.security_compliance.static_keys' .mcp.json 2>/dev/null || echo "true")
    
    if [ "$STATIC_KEYS" == "false" ]; then
        success "Static keys disabled in MCP config"
    else
        critical "Static keys NOT disabled in MCP config"
    fi
    
    # Check JIT retrieval
    KEY_RETRIEVAL=$(jq -r '.security_compliance.key_retrieval' .mcp.json 2>/dev/null || echo "static")
    
    if [ "$KEY_RETRIEVAL" == "jit" ]; then
        success "Just-in-time key retrieval configured"
    else
        error "JIT key retrieval not configured (found: $KEY_RETRIEVAL)"
    fi
else
    critical ".mcp.json not found"
fi

###############################################################################
# Audit 3: Docker Network Security
###############################################################################

header "Audit 3: Docker Network Security"

info "Checking Docker port bindings..."

if docker info >/dev/null 2>&1; then
    # Check Qdrant port bindings
    if docker ps --format '{{.Names}}' | grep -q "qdrant-pod"; then
        QDRANT_BINDINGS=$(docker port qdrant-pod 2>/dev/null || echo "none")
        
        if echo "$QDRANT_BINDINGS" | grep -q "127.0.0.1"; then
            success "Qdrant bound to localhost only"
        else
            critical "Qdrant NOT bound to localhost exclusively"
            echo "  Bindings: $QDRANT_BINDINGS"
        fi
    else
        info "Qdrant container not running - skipping port check"
    fi
    
    # Check Neo4j port bindings
    if docker ps --format '{{.Names}}' | grep -q "neo4j-pod"; then
        NEO4J_BINDINGS=$(docker port neo4j-pod 2>/dev/null || echo "none")
        
        if echo "$NEO4J_BINDINGS" | grep -q "127.0.0.1"; then
            success "Neo4j bound to localhost only"
        else
            critical "Neo4j NOT bound to localhost exclusively"
            echo "  Bindings: $NEO4J_BINDINGS"
        fi
    else
        info "Neo4j container not running - skipping port check"
    fi
    
    # Check for exposed ports
    EXPOSED=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "127.0.0.1" | grep -v "PORTS" || true)
    
    if [ -z "$EXPOSED" ]; then
        success "No externally exposed Docker ports"
    else
        critical "Externally exposed Docker ports detected:"
        echo "$EXPOSED"
    fi
else
    info "Docker not running - skipping network security checks"
fi

###############################################################################
# Audit 4: File Permissions
###############################################################################

header "Audit 4: File Permissions"

info "Checking sensitive file permissions..."

# Check .env permissions (if exists)
if [ -f ".env" ]; then
    if [ "$(uname)" == "Linux" ] || [ "$(uname)" == "Darwin" ]; then
        PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%A" .env 2>/dev/null || echo "unknown")
        
        if [ "$PERMS" == "600" ] || [ "$PERMS" == "400" ]; then
            success ".env permissions secure: $PERMS"
        else
            error ".env permissions too permissive: $PERMS (should be 600 or 400)"
        fi
    else
        info "File permission check skipped on Windows"
    fi
fi

# Check memory JSON files
for MEMORY_FILE in .claude/memories/*.json; do
    if [ -f "$MEMORY_FILE" ]; then
        if [ "$(uname)" == "Linux" ] || [ "$(uname)" == "Darwin" ]; then
            PERMS=$(stat -c "%a" "$MEMORY_FILE" 2>/dev/null || stat -f "%A" "$MEMORY_FILE" 2>/dev/null || echo "unknown")
            FILENAME=$(basename "$MEMORY_FILE")
            
            if [ "$PERMS" == "600" ] || [ "$PERMS" == "644" ] || [ "$PERMS" == "640" ]; then
                success "$FILENAME permissions acceptable: $PERMS"
            else
                error "$FILENAME permissions too permissive: $PERMS"
            fi
        fi
    fi
done

###############################################################################
# Audit 5: Secret Management
###############################################################################

header "Audit 5: Secret Management"

info "Checking secret management configuration..."

# Check for AWS Secrets Manager references
if [ -f ".env.example" ]; then
    VAULT_REFS=$(grep -c "VAULT_PATH" .env.example || echo "0")
    
    if [ "$VAULT_REFS" -gt 0 ]; then
        success "AWS Secrets Manager references found in .env.example"
    else
        error "No AWS Secrets Manager references found"
    fi
fi

# Check security-config.md exists
if [ -f "security-config.md" ]; then
    success "security-config.md documentation exists"
    
    # Check it references AWS Secrets Manager
    if grep -q "AWS Secrets Manager" security-config.md; then
        success "security-config.md references AWS Secrets Manager"
    else
        error "security-config.md doesn't reference AWS Secrets Manager"
    fi
else
    error "security-config.md not found"
fi

###############################################################################
# Audit 6: Sensitive Data in Git
###############################################################################

header "Audit 6: Git Repository Security"

info "Checking for sensitive data in git..."

if [ -d ".git" ]; then
    # Check .gitignore exists
    if [ -f ".gitignore" ]; then
        success ".gitignore file exists"
        
        # Check for essential ignores
        IGNORES=(".env" "*.key" "*.pem" "secrets/" "credentials/")
        
        for IGNORE in "${IGNORES[@]}"; do
            if grep -q "$IGNORE" .gitignore; then
                success ".gitignore includes: $IGNORE"
            else
                error ".gitignore missing: $IGNORE"
            fi
        done
    else
        critical ".gitignore file NOT found"
    fi
    
    # Check if .env is tracked
    if git ls-files --error-unmatch .env >/dev/null 2>&1; then
        critical ".env file is tracked by git!"
    else
        success ".env file not tracked by git"
    fi
else
    info "Not a git repository - skipping git security checks"
fi

###############################################################################
# Audit 7: Configuration File Security
###############################################################################

header "Audit 7: Configuration File Security"

info "Checking configuration files..."

# Check docker-compose.yml for hardcoded passwords
if [ -f "docker-compose.yml" ]; then
    PASSWORDS=$(grep -i "password" docker-compose.yml | grep -v "CHANGE_ME" | grep -v "example" | grep -v "your-password" || true)
    
    if [ -z "$PASSWORDS" ]; then
        success "No hardcoded passwords in docker-compose.yml"
    else
        critical "Potential hardcoded passwords in docker-compose.yml"
    fi
fi

# Check for exposed credentials in skill configs
EXPOSED_CREDS=$(grep -r "password\|secret\|token" .claude/skills --include="*.json" --include="*.md" 2>/dev/null | grep -v "example" | grep -v "your-" || true)

if [ -z "$EXPOSED_CREDS" ]; then
    success "No exposed credentials in skill configurations"
else
    error "Potential credentials in skill configurations"
fi

###############################################################################
# Audit 8: Script Execution Security
###############################################################################

header "Audit 8: Script Execution Security"

info "Checking script security..."

# Check for scripts without proper validation
for SCRIPT in .claude/skills/*/scripts/*.py; do
    if [ -f "$SCRIPT" ]; then
        SCRIPT_NAME=$(basename "$SCRIPT")
        
        # Check for input validation (basic check)
        if grep -q "sys.argv" "$SCRIPT"; then
            if grep -q "len(sys.argv)" "$SCRIPT" || grep -q "try:" "$SCRIPT"; then
                success "$SCRIPT_NAME has basic input validation"
            else
                error "$SCRIPT_NAME may lack input validation"
            fi
        fi
    fi
done

###############################################################################
# Security Score Summary
###############################################################################

header "Security Audit Summary"

TOTAL_CHECKS=$((CHECKS_PASSED + CHECKS_FAILED))

if [ $TOTAL_CHECKS -gt 0 ]; then
    PASS_RATE=$((CHECKS_PASSED * 100 / TOTAL_CHECKS))
    
    echo "Security Score: ${PASS_RATE}%"
    echo ""
    echo "Checks Passed: $CHECKS_PASSED"
    echo "Checks Failed: $CHECKS_FAILED"
    echo "Critical Issues: $CRITICAL_ISSUES"
    echo ""
fi

# Security rating
if [ $CRITICAL_ISSUES -eq 0 ]; then
    if [ $PASS_RATE -ge 90 ]; then
        echo -e "${GREEN}Security Rating: EXCELLENT${NC}"
    elif [ $PASS_RATE -ge 75 ]; then
        echo -e "${YELLOW}Security Rating: GOOD${NC}"
    else
        echo -e "${YELLOW}Security Rating: FAIR${NC}"
    fi
else
    echo -e "${RED}Security Rating: NEEDS ATTENTION${NC}"
    echo ""
    echo "CRITICAL ISSUES MUST BE ADDRESSED:"
    echo "  • $CRITICAL_ISSUES critical security issues found"
    echo "  • Review audit output above for details"
fi

echo ""

###############################################################################
# Recommendations
###############################################################################

header "Security Recommendations"

echo "1. API Key Management:"
echo "   • Use AWS Secrets Manager for all API keys"
echo "   • Enable OAuth-only authentication"
echo "   • Implement just-in-time key retrieval"
echo ""
echo "2. Network Security:"
echo "   • Bind all Docker services to localhost only"
echo "   • Use firewall rules for additional protection"
echo "   • Monitor network connections"
echo ""
echo "3. File Security:"
echo "   • Set restrictive permissions on .env (600)"
echo "   • Add sensitive files to .gitignore"
echo "   • Never commit secrets to version control"
echo ""
echo "4. Ongoing Security:"
echo "   • Run this audit regularly"
echo "   • Review logs for suspicious activity"
echo "   • Keep dependencies updated"
echo ""

###############################################################################
# Exit Status
###############################################################################

if [ $CRITICAL_ISSUES -gt 0 ]; then
    echo -e "${RED}AUDIT FAILED: Critical security issues must be resolved${NC}"
    exit 1
elif [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${YELLOW}AUDIT WARNING: Some security checks failed${NC}"
    exit 1
else
    echo -e "${GREEN}AUDIT PASSED: All security checks passed${NC}"
    exit 0
fi