#!/bin/bash
# Optional reload helper for local .env credentials (no automatic rotation)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

source ".claude/scripts/fetch-docker-secrets.sh"

docker-compose up -d --force-recreate qdrant neo4j

mkdir -p ".claude/data/logs"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"action\":\"env_reloaded\"}" >> ".claude/data/logs/mcp_calls.jsonl"
