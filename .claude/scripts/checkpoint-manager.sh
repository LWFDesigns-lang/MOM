#!/usr/bin/env bash
set -euo pipefail

CLAUDE_CLI=${CLAUDE_CLI:-claude}
CHECKPOINT_DIR=".claude/data/checkpoints"
LOG_FILE=".claude/data/logs/context.jsonl"
MAX_KEEP=10
AUTO_TOKEN_INTERVAL=50000
AUTO_COUNTER_FILE=".claude/data/checkpoints/token-counter.txt"

mkdir -p "$CHECKPOINT_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$AUTO_COUNTER_FILE")"

current_tokens=$($CLAUDE_CLI /context | grep -oE '[0-9]+' | head -n 1 || echo "0")
current_tokens=${current_tokens:-0}
timestamp=$(date -u +"%Y%m%dT%H%M%SZ")

function log_checkpoint {
  local action=$1
  local label=$2
  echo "{\"timestamp\":\"$timestamp\",\"action\":\"$action\",\"label\":\"$label\",\"tokens\":$current_tokens}" >> "$LOG_FILE"
}

function list_checkpoints {
  echo "Available checkpoints:"
  ls -1t "$CHECKPOINT_DIR"/*.meta 2>/dev/null | while read meta; do
    jq -r '.label + " | tokens:" + (.tokens|tostring) + " | created:" + .created_at' "$meta"
  done
}

function create_checkpoint {
  local label=$1
  local safe_label=${label// /_}
  local meta="$CHECKPOINT_DIR/$timestamp-$safe_label.meta"
  local data="$CHECKPOINT_DIR/$timestamp-$safe_label.dat"

  $CLAUDE_CLI /checkpoint "\"$label\""
  cat <<EOF > "$meta"
{"label":"$label","tokens":$current_tokens,"created_at":"$timestamp"}
EOF
  touch "$data"
  maintain_checkpoint_limit
  log_checkpoint "create" "$label"
  echo "Checkpoint '$label' created (tokens: $current_tokens)."
}

function maintain_checkpoint_limit {
  local total
  total=$(ls -1 "$CHECKPOINT_DIR"/*.meta 2>/dev/null | wc -l)
  while (( total > MAX_KEEP )); do
    local oldest
    oldest=$(ls -1 "$CHECKPOINT_DIR"/*.meta | head -n 1)
    rm -f "$oldest" "$CHECKPOINT_DIR/$(basename "$oldest" .meta).dat" 2>/dev/null || true
    total=$((total - 1))
  done
}

function delete_checkpoint {
  local label=$1
  local matched=$(grep -l "\"$label\"" "$CHECKPOINT_DIR"/*.meta 2>/dev/null || true)
  if [[ -n "$matched" ]]; then
    rm -f "$matched" "$CHECKPOINT_DIR/$(basename "$matched" .meta).dat"
    log_checkpoint "delete" "$label"
    echo "Deleted checkpoint(s) matching '$label'."
  else
    echo "No checkpoint found for '$label'."
  fi
}

function restore_checkpoint {
  local label=$1
  $CLAUDE_CLI /restore "\"$label\""
  log_checkpoint "restore" "$label"
  echo "Restored checkpoint '$label'."
}

function auto_checkpoint_check {
  local counter=0
  if [[ -f "$AUTO_COUNTER_FILE" ]]; then
    counter=$(cat "$AUTO_COUNTER_FILE")
  fi
  counter=$((counter + current_tokens))
  echo "$counter" > "$AUTO_COUNTER_FILE"
  if (( counter >= AUTO_TOKEN_INTERVAL )); then
    local auto_label="auto_$timestamp"
    create_checkpoint "$auto_label"
    echo "Auto checkpoint triggered at $counter tokens."
    echo 0 > "$AUTO_COUNTER_FILE"
  fi
}

case "${1:-}" in
  create)
    shift
    create_checkpoint "${*:-manual}"
    ;;
  list)
    list_checkpoints
    ;;
  restore)
    shift
    restore_checkpoint "${*:-last}"
    ;;
  delete)
    shift
    delete_checkpoint "${*:-old}"
    ;;
  auto)
    auto_checkpoint_check
    ;;
  *)
    echo "Usage: $0 {create|list|restore|delete|auto} [label]"
    ;;
esac