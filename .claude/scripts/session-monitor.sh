#!/usr/bin/env bash
set -euo pipefail

CLAUDE_CLI=${CLAUDE_CLI:-claude}
STATE_FILE=".claude/data/logs/session-state.json"
METRICS_FILE=".claude/data/logs/session-metrics.json"
LOG_FILE=".claude/data/logs/context.jsonl"
BASE_TOKENS=200000

mkdir -p "$(dirname "$LOG_FILE")"

if [[ ! -f "$STATE_FILE" ]]; then
  session_id=$(uuidgen)
  start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat <<EOF > "$STATE_FILE"
{"session_id":"$session_id","start_time":"$start_time"}
EOF
else
  session_id=$(jq -r '.session_id' "$STATE_FILE")
  start_time=$(jq -r '.start_time' "$STATE_FILE")
fi

if [[ ! -f "$METRICS_FILE" ]]; then
  cat <<EOF > "$METRICS_FILE"
{"skills_executed":0,"mcp_calls":0,"checkpoints":0}
EOF
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) jq '.skills_executed += 1' "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE" ;;
    --mcp) jq '.mcp_calls += 1' "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE" ;;
    --checkpoint) jq '.checkpoints += 1' "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE" ;;
    *) echo "Unknown flag: $1" ;;
  esac
  shift
done

current_tokens=$($CLAUDE_CLI /context | grep -oE '[0-9]+' | head -n 1 || echo "0")
current_tokens=${current_tokens:-0}
start_epoch=$(date -d "$start_time" +%s)
now_epoch=$(date -u +%s)
elapsed_seconds=$(( now_epoch - start_epoch ))
elapsed_minutes=$(( elapsed_seconds / 60 ))
elapsed_minutes=$(( elapsed_minutes > 0 ? elapsed_minutes : 1 ))

token_rate=$(( current_tokens / elapsed_minutes ))
time_to_limit_minutes=$(( (BASE_TOKENS - current_tokens) > 0 ? (BASE_TOKENS - current_tokens) / (token_rate > 0 ? token_rate : 1) : 0 ))

skills_executed=$(jq '.skills_executed' "$METRICS_FILE")
mcp_calls=$(jq '.mcp_calls' "$METRICS_FILE")
checkpoints=$(jq '.checkpoints' "$METRICS_FILE")

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat <<EOF
Session ID: $session_id
Start Time: $start_time (UTC)
Elapsed: $elapsed_seconds seconds (~$elapsed_minutes minutes)
Current Tokens: $current_tokens
Token Rate: $token_rate tokens/minute
Predicted Time to Limit: $time_to_limit_minutes minutes
Skills Executed: $skills_executed
MCP Calls: $mcp_calls
Checkpoints Created: $checkpoints
EOF

jq -n \
  --arg ts "$timestamp" \
  --arg session "$session_id" \
  --arg start "$start_time" \
  --argjson tokens "$current_tokens" \
  --argjson rate "$token_rate" \
  --argjson time_to_limit "$time_to_limit_minutes" \
  --argjson skills "$skills_executed" \
  --argjson mcp "$mcp_calls" \
  --argjson checkpoints "$checkpoints" \
  '{"timestamp":$ts,"session_id":$session,"start_time":$start,"current_tokens":$tokens,"token_rate":$rate,"time_to_limit_minutes":$time_to_limit,"skills_executed":$skills,"mcp_calls":$mcp,"checkpoints":$checkpoints}' \
  >> "$LOG_FILE"