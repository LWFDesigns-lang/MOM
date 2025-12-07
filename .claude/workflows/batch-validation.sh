#!/bin/bash
# Batch validation workflow using validation-specialist subagents.
# Requirements: Claude Code CLI + jq installed. Designed for Linux/macOS cron or GitHub Actions.
# Token budget: 2,500 tokens per niche (enforced via reported metadata).

set -euo pipefail

WORKERS=${WORKERS:-4}
BUDGET_PER_NICHE=2500
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR=".claude/data/logs"
RESULTS_DIR=".claude/data/results"
TMP_DIR=".claude/data/cache/batch_validation_tmp"
REPORT_FILE="$RESULTS_DIR/batch_validation_${TIMESTAMP}.json"
LOG_FILE="$LOG_DIR/batch_validation_${TIMESTAMP}.log"
FAIL_FLAG="$TMP_DIR/fail.flag"

mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$TMP_DIR"

trap 'echo "Batch validation exiting at $(date --iso-8601=seconds)" | tee -a "$LOG_FILE"' EXIT

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found" | tee -a "$LOG_FILE"
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" | tee -a "$LOG_FILE"
  exit 3
fi

echo "=== Batch Validation ===" | tee -a "$LOG_FILE"
echo "Workers: $WORKERS" | tee -a "$LOG_FILE"
echo "Token budget per niche: $BUDGET_PER_NICHE" | tee -a "$LOG_FILE"

NICHES=()
INPUT_FILE=""
while getopts "i:w:h" flag; do
  case "$flag" in
    i) INPUT_FILE="$OPTARG" ;;
    w) WORKERS="$OPTARG" ;;
    h) echo "Usage: $0 [-i niche-file] [niche1 niche2 ...]" && exit 0 ;;
    *) echo "Invalid option" && exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ -n "$INPUT_FILE" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: Input file $INPUT_FILE not found" | tee -a "$LOG_FILE"
    exit 4
  fi
  mapfile -t NICHES < <(grep -Ev '^\s*$' "$INPUT_FILE")
elif [[ $# -gt 0 ]]; then
  NICHES=("$@")
else
  echo "ERROR: No niches provided" | tee -a "$LOG_FILE"
  exit 5
fi

if [[ ${#NICHES[@]} -eq 0 ]]; then
  echo "ERROR: Niche list is empty" | tee -a "$LOG_FILE"
  exit 6
fi

RESULT_FILES=()
FAILURES=0

run_validation() {
  local niche="$1"
  local index="$2"
  local result_path="$TMP_DIR/validation_${index}.json"
  local payload
  payload=$(jq -n --arg niche "$niche" '{niche: $niche}')

  set +e
  claude subagent run validation-specialist \
    --input "$payload" \
    --output-format json > "$result_path" 2>> "$LOG_FILE"
  local status=$?
  set -e

  if [ $status -ne 0 ]; then
    echo "{\"niche\":\"$niche\",\"error\":\"claude exit $status\"}" > "$result_path"
    echo 1 > "$FAIL_FLAG"
    echo "ERROR: validation failed for '$niche' (exit $status)" | tee -a "$LOG_FILE"
  fi

  local tokens
  tokens=$(jq -r '.metadata.tokens // .metadata.tokenCount // .tokensUsed // 0' "$result_path" 2>/dev/null || echo 0)
  if [[ -z "$tokens" ]]; then
    tokens=0
  fi

  echo "Niche: $niche used $tokens tokens" | tee -a "$LOG_FILE"
  if (( tokens > BUDGET_PER_NICHE )); then
    echo "ERROR: Token budget exceeded for '$niche' ($tokens > $BUDGET_PER_NICHE)" | tee -a "$LOG_FILE"
    echo 1 > "$FAIL_FLAG"
  fi

  RESULT_FILES+=("$result_path")
}

run_in_background() {
  local niche="$1"
  local idx="$2"
  run_validation "$niche" "$idx"
}

index=0
for niche in "${NICHES[@]}"; do
  index=$((index + 1))
  while (( $(jobs -rp | wc -l) >= WORKERS )); do
    sleep 0.5
  done
  run_in_background "$niche" "$index" &
done

wait

if [[ -f "$FAIL_FLAG" ]]; then
  echo "One or more validations failed" | tee -a "$LOG_FILE"
  exit 7
fi

if [[ ${#RESULT_FILES[@]} -eq 0 ]]; then
  echo "No results generated" | tee -a "$LOG_FILE"
  exit 8
fi

jq -s . "${RESULT_FILES[@]}" > "$REPORT_FILE"
echo "Batch report saved to $REPORT_FILE" | tee -a "$LOG_FILE"
echo "Completed with $(jq 'length' "$REPORT_FILE") results" | tee -a "$LOG_FILE"