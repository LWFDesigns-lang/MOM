#!/usr/bin/env bash
set -euo pipefail

CLAUDE_CLI=${CLAUDE_CLI:-claude}
LOG_FILE=".claude/data/logs/context.jsonl"
RULES_FILE=".claude/config/context-rules.yaml"
BASE_TOKENS=200000
MICROCOMPACT_THRESHOLD=180000
GREEN_THRESHOLD=150000
AVG_SKILL_COST=2500  # approximate tokens per skill chain

mkdir -p "$(dirname "$LOG_FILE")"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
context_output=$($CLAUDE_CLI /context 2>&1 || true)
current_tokens=$(echo "$context_output" | grep -oE '[0-9]+' | head -n 1 || echo "0")
current_tokens=${current_tokens:-0}

percent_used=$(( current_tokens * 100 / BASE_TOKENS ))
remaining_tokens=$(( BASE_TOKENS > current_tokens ? BASE_TOKENS - current_tokens : 0 ))
operations_remaining=$(( remaining_tokens / AVG_SKILL_COST ))
operation_history=$(( current_tokens / AVG_SKILL_COST ))

warning_color="\033[0m"
message="Context healthy. Continue skill chains."
recommended_action="Maintain workflow and watch budgets."

if (( current_tokens >= MICROCOMPACT_THRESHOLD )); then
  warning_color="\033[1;31m"
  message="Microcompact recommended immediately."
  recommended_action="Run /compact or rely on automatic microcompact."
elif (( current_tokens >= GREEN_THRESHOLD )); then
  warning_color="\033[1;33m"
  message="Context approaching 180K. Consider checkpoint + microcompact."
  recommended_action="Create checkpoint, plan for /compact soon."
else
  warning_color="\033[1;32m"
fi

reset_color="\033[0m"

cat <<EOF
${warning_color}CLAUDE /context snapshot${reset_color}
Tokens used: ${current_tokens}/${BASE_TOKENS} (${percent_used}%)
Estimated skill chains consumed: ~${operation_history}
Estimated remaining chains: ~${operations_remaining}
${message}
Recommended action: ${recommended_action}
Efficiency metric: ${percent_used}% of ${BASE_TOKENS} window used.
EOF

cat <<EOF >> "$LOG_FILE"
{"timestamp":"$timestamp","type":"context_snapshot","tokens_used":$current_tokens,"percent_used":$percent_used,"remaining_tokens":$remaining_tokens,"operation_history":$operation_history,"operations_remaining":$operations_remaining,"recommended_action":"$recommended_action"}
EOF

if (( current_tokens >= MICROCOMPACT_THRESHOLD )); then
  echo -e "\033[1;31m⚠ Microcompact trigger reached. Run /compact or await automatic microcompact.\033[0m"
fi