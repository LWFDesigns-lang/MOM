#!/usr/bin/env bash
set -euo pipefail

CLAUDE_CLI=${CLAUDE_CLI:-claude}
LOG_FILE=".claude/data/logs/context.jsonl"
AUTO_THRESHOLD=180000
MANUAL_FLAG=false
SCHEDULE_LIMIT=30
OPERATION_COUNT_FILE=".claude/data/logs/operation-count.txt"

mkdir -p "$(dirname "$LOG_FILE")"

if [[ ! -f "$OPERATION_COUNT_FILE" ]]; then
  echo "0" > "$OPERATION_COUNT_FILE"
fi

operation_count=$(cat "$OPERATION_COUNT_FILE")
operation_count=$((operation_count + 1))
echo "$operation_count" > "$OPERATION_COUNT_FILE"

current_tokens=$($CLAUDE_CLI /context | grep -oE '[0-9]+' | head -n 1 || echo "0")
current_tokens=${current_tokens:-0}
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

run_compact() {
  before=$current_tokens
  $CLAUDE_CLI /compact > /dev/null
  after=$($CLAUDE_CLI /context | grep -oE '[0-9]+' | head -n 1 || echo "0")
  savings=$((before - after))
  ratio=$(awk "BEGIN { printf \"%.2f\", ($after > 0 ? $before / $after : 0) }")
  echo "{\"timestamp\":\"$timestamp\",\"action\":\"compact\",\"before\":$before,\"after\":$after,\"savings\":$savings,\"ratio\":$ratio}" >> "$LOG_FILE"
  echo -e "Compact completed. Tokens before: $before, after: $after, saved: $savings, ratio: $ratio"
}

if [[ "${1:-}" == "--manual" ]]; then
  MANUAL_FLAG=true
fi

if (( current_tokens >= AUTO_THRESHOLD )) || $MANUAL_FLAG || (( operation_count % SCHEDULE_LIMIT == 0 )); then
  echo "Triggering context cleanup..."
  run_compact
else
  echo "No cleanup needed (current tokens: $current_tokens, threshold: $AUTO_THRESHOLD)."
fi