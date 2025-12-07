#!/bin/bash
# Loads Docker service credentials from local .env (home/single-user convenience)
set -euo pipefail

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "WARNING: $ENV_FILE not found. Create it with QDRANT_API_KEY, QDRANT_READONLY_KEY, NEO4J_PASSWORD, etc."
  exit 1
fi

set -o allexport
source "$ENV_FILE"
set +o allexport

mkdir -p ".claude/data/logs"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"action\":\"credentials_loaded\",\"source\":\".env\"}" >> ".claude/data/logs/mcp_calls.jsonl"
