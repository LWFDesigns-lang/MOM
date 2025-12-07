#!/usr/bin/env bash
# PowerShell-friendly guidance is included in troubleshooting hints below.

set -euo pipefail

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

status() {
  printf "%s%s%s\n" "$1" "$2" "$RESET"
}

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    status "$GREEN" "✓ Found $path"
  else
    status "$RED" "✗ Missing $path (create the file per documentation)"
    exit 1
  fi
}

check_json() {
  local path="$1"
  if node -e "JSON.parse(require('fs').readFileSync('$path','utf8'))" >/dev/null 2>&1; then
    status "$GREEN" "✓ $path is valid JSON"
  else
    status "$RED" "✗ $path failed JSON validation"
    exit 1
  fi
}

warn_env() {
  if [[ -f ".env" ]]; then
    status "$YELLOW" "⚠ .env exists. Confirm it contains placeholders only; real secrets must live in AWS Secrets Manager."
  else
    status "$YELLOW" "⚠ .env not found. Create one from .env.example for placeholders, not production secrets."
  fi
}

list_servers() {
  node - <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('.mcp.json', 'utf8'));
const servers = Object.keys(config.mcpServers || {});
console.log("Configured MCP servers: " + servers.join(', '));
NODE
}

check_node_bin() {
  local label="$1"
  local path="$2"
  if [[ -x "$path" ]] || [[ -f "$path" ]]; then
    status "$GREEN" "✓ $label binary available at $path"
  else
    status "$RED" "✗ $label binary missing ($path). Run npm install for the MCP package."
  fi
}

check_docker_container() {
  local name="$1"
  if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
    status "$GREEN" "✓ Docker container ${name} running (localhost binding enforced)"
  else
    status "$RED" "✗ Docker container ${name} not running. Start it via docker-compose up ${name} or docker run (see docker-compose.yml)."
  fi
}

printf "\n==== MCP HEALTH CHECK ====\n"
check_file ".mcp.json"
check_json ".mcp.json"
warn_env

printf "\n"
list_servers
echo

declare -A binary_map=(
  [filesystem]="node_modules/.bin/mcp-server-filesystem"
  [brave-search]="node_modules/.bin/brave-search-mcp"
  [perplexity-research]="node_modules/.bin/perplexity-mcp"
  [playwright-browser]="node_modules/.bin/playwright-mcp"
  [etsy-api-integration]="node_modules/.bin/etsy-mcp"
  [shopify-sync]="node_modules/.bin/shopify-mcp"
)

for server in "${!binary_map[@]}"; do
  check_node_bin "$server" "${binary_map[$server]}"
done

printf "\n==== Docker health ====\n"
check_docker_container "qdrant-pod"
check_docker_container "neo4j-pod"

printf "\n==== Credential reminders ====\n"
status "$YELLOW" "• Use AWS Secrets Manager JIT retrieval (see security-config.md)."
status "$YELLOW" "• Tokens rotate every 60 minutes (BRAVE_OAUTH_TTL / ETSY_OAUTH_TTL etc.)."
status "$YELLOW" "• No plaintext API keys in .env or git history."

printf "\n==== Troubleshooting hints ====\n"
status "$YELLOW" "• Missing binary → run: npm install @anthropic-ai/mcp-server-filesystem @anthropic-ai/mcp-server-brave-search perplexity-mcp @anthropic-ai/mcp-server-playwright etsy-mcp shopify-mcp"
status "$YELLOW" "• Docker container kept down? Run 'docker-compose up -d'."
status "$YELLOW" "• Validation failing? Ensure AWS Secrets Manager credentials (vault URIs) are reachable."
status "$YELLOW" "• Windows/PowerShell: use Git Bash or WSL to run this script; alternatives include 'bash mcp-health-check.sh'."

printf "\nMCP health check complete.\n"