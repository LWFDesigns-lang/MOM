#!/bin/bash
# Startup helper for local/home setup using .env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

source ".claude/scripts/fetch-docker-secrets.sh"

docker-compose up -d
echo "Services started with .env credentials (no rotation configured)."
