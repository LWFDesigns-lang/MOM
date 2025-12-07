#!/bin/bash
# Daily niche discovery workflow (headless)
# Requirements: Claude Code CLI installed and configured. Compatible with cron.

set -euo pipefail

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR=".claude/data/logs"
RESULTS_DIR=".claude/data/results"
CHECKPOINT_DIR=".claude/data/checkpoints"
mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$CHECKPOINT_DIR"

LOG_FILE="$LOG_DIR/workflow_${TIMESTAMP}.log"
RESULTS_FILE="$RESULTS_DIR/niches_${TIMESTAMP}.json"

trap '{
  status=$?
  echo "Completed with status: $status" | tee -a "$LOG_FILE"
  if [ $status -ne 0 ]; then
    echo "Daily niche discovery failed. Check $LOG_FILE for details." >&2
  fi
}' EXIT

if ! command -v claude &> /dev/null; then
  echo "ERROR: claude CLI not found in PATH." | tee -a "$LOG_FILE"
  exit 2
fi

echo "=== Daily Niche Discovery ===" | tee -a "$LOG_FILE"
echo "Started at: $(date --iso-8601=seconds)" | tee -a "$LOG_FILE"
echo "Token budget target: 3-5 niches @ 2-3K tokens each" | tee -a "$LOG_FILE"

PROMPT=$(cat <<'EOF'
Validate five trending POD niches with the pod-research skill. Use fresh context for each, gather Etsy count + Google Trends data via MCP (data-etsy + data-trends), and call logic-validator. Output a JSON array with one result per niche. Niches:
1. sustainable home decor
2. minimalist pet accessories
3. retro gaming nostalgia
4. tactile journal stationery
5. plant-inspired fitness gear

For each niche:
1. Fetch Etsy listings with data-etsy.
2. Fetch 12-month trend stability with data-trends.
3. Run logic-validator.validate_niche.
4. Return the structured decision (GO/SKIP, confidence, etsy_count, trend_score, reasoning).
Do not include markdown or explanation. Output only JSON array.
EOF
)

{
  set +e
  claude -p "$PROMPT" --output-format json > "$RESULTS_FILE" 2>> "$LOG_FILE"
  status=$?
  set -e
  if [ $status -ne 0 ]; then
    echo "Claude invocation failed with exit code $status" | tee -a "$LOG_FILE"
    exit $status
  fi
} 

GO_COUNT=$(grep -o '"decision": "GO"' "$RESULTS_FILE" | wc -l | tr -d ' ')
echo "GO decisions: $GO_COUNT" | tee -a "$LOG_FILE"

echo "Results saved: $RESULTS_FILE" | tee -a "$LOG_FILE"
echo "Completed at: $(date --iso-8601=seconds)" | tee -a "$LOG_FILE"

exit 0