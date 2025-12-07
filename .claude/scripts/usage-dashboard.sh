#!/bin/bash
# CLI token usage dashboard for POD automation.
# Requirements: jq installed, .claude/data/logs directory populated by token-monitor.

set -euo pipefail

LOG_DIR=".claude/data/logs"
TODAY=$(date +"%Y%m%d")
LOG_FILE="$LOG_DIR/tokens_${TODAY}.json"

echo "════════════════════════════════════════════════════════"
echo "           POD AUTOMATION TOKEN USAGE DASHBOARD         "
echo "════════════════════════════════════════════════════════"

if [[ -f "$LOG_FILE" ]]; then
  echo ""
  echo "Today's Usage Summary ($(date +"%Y-%m-%d")):"
  jq -r '
    "  Session total tokens: \(.session_total)",
    "  Breakdown by workflow:",
    (.by_workflow | to_entries[] | "    • \(.key): \(.value) tokens")
  ' "$LOG_FILE"
else
  echo ""
  echo "No usage data available for today yet."
fi

echo ""
echo "Budget Reference:"
echo "  • single_niche_validation: budget=5,000 ⚠ warning=4,000"
echo "  • batch_validation_5: budget=15,000 ⚠ warning=12,000 (per niche cap=2,500)"
echo "  • design_ideation: budget=8,000 ⚠ warning=6,500"
echo "  • listing_creation: budget=10,000 ⚠ warning=8,000"
echo "  • full_pipeline: budget=40,000 ⚠ warning=30,000"

echo ""
echo "Cost Projections:"
if [[ -f "$LOG_FILE" ]]; then
  DAILY_TOTAL=$(jq -r '.session_total // 0' "$LOG_FILE")
  echo "  Estimated daily spend (tokens × $0.0001): $(( DAILY_TOTAL * 1 / 10000 ))"
else
  echo "  No token usage logged today yet."
fi

echo ""
echo "Warnings:"
if command -v jq &> /dev/null && [[ -f "$LOG_FILE" ]]; then
  jq -r '
    .by_workflow | to_entries[]
    | select(.value >= 0)
    | "  • \(.key): \(.value) tokens"
  ' "$LOG_FILE"
else
  echo "  Ensure token-monitor is running to capture usage."
fi