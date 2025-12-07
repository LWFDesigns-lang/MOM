#!/bin/bash
# Full POD pipeline: research → design → pricing → listing
# Headless, checkpointed, rollback-aware. Target token budget: 8-12K.
# Requirements: claude CLI, jq, unix shell (Linux/macOS). Works with cron or scheduler.

set -euo pipefail

NICHE=${1:-"sustainable home decor"}
PRODUCT=${2:-"tee_standard"}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR=".claude/data/logs"
RESULTS_DIR=".claude/data/results"
CHECKPOINT_DIR=".claude/data/checkpoints"
REPORT_FILE="$RESULTS_DIR/full_pipeline_${TIMESTAMP}.json"
LOG_FILE="$LOG_DIR/full_pipeline_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$CHECKPOINT_DIR"

CURRENT_STAGE=""
LAST_SUCCESS_STAGE=""

trap 'status=$?
if [ $status -ne 0 ]; then
  echo "Pipeline failed at stage: $CURRENT_STAGE" | tee -a "$LOG_FILE"
  rollback
else
  echo "Pipeline completed successfully" | tee -a "$LOG_FILE"
fi
' EXIT

function log() {
  echo "$(date --iso-8601=seconds) - $1" | tee -a "$LOG_FILE"
}

function checkpoint() {
  local stage="$1"
  local payload="$2"
  cp "$payload" "$CHECKPOINT_DIR/${stage}_${TIMESTAMP}.json"
  LAST_SUCCESS_STAGE="$stage"
  log "Checkpoint saved [$stage]"
}

function rollback() {
  if [ -n "$LAST_SUCCESS_STAGE" ] && [ -f "$CHECKPOINT_DIR/${LAST_SUCCESS_STAGE}_${TIMESTAMP}.json" ]; then
    log "Rolling back to checkpoint: $LAST_SUCCESS_STAGE"
    cat "$CHECKPOINT_DIR/${LAST_SUCCESS_STAGE}_${TIMESTAMP}.json" >> "$LOG_FILE"
  else
    log "No checkpoint available to rollback"
  fi
}

function run_stage() {
  local stage="$1"
  local prompt="$2"
  local output="$3"
  CURRENT_STAGE="$stage"
  log "Starting stage: $stage"
  if ! claude -p "$prompt" --output-format json > "$output" 2>> "$LOG_FILE"; then
    log "Claude stage $stage failed"
    exit 10
  fi
  checkpoint "$stage" "$output"
  log "Stage $stage complete"
}

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI is required but not found" | tee -a "$LOG_FILE"
  exit 1
fi

log "Full pipeline initiated for niche='$NICHE', product='$PRODUCT'"
log "Token budget target: 8K-12K tokens total"

STAGE1_FILE="$RESULTS_DIR/full_pipeline_stage1_${TIMESTAMP}.json"
STAGE2_FILE="$RESULTS_DIR/full_pipeline_stage2_${TIMESTAMP}.json"
STAGE3_FILE="$RESULTS_DIR/full_pipeline_stage3_${TIMESTAMP}.json"
STAGE4_FILE="$RESULTS_DIR/full_pipeline_stage4_${TIMESTAMP}.json"

STAGE1_PROMPT=$(cat <<EOF
Use the pod-research skill to validate the niche "$NICHE". Return exactly the JSON result from pod-research (decision, confidence, etsy_count, trend_score, brand_assignment, reasoning). Do not add prose.
EOF
)

run_stage "research" "$STAGE1_PROMPT" "$STAGE1_FILE"

DECISION=$(jq -r '.decision' "$STAGE1_FILE")
if [ "$DECISION" != "GO" ]; then
  log "Niche decision is SKIP ($DECISION). Exiting pipeline."
  exit 0
fi

BRAND=$(jq -r '.brand_assignment // "LWF"' "$STAGE1_FILE")

STAGE2_PROMPT=$(cat <<EOF
The niche "$NICHE" belongs to brand "$BRAND". Use pod-design-review to generate five design concepts. Return JSON containing niche, brand, concepts (id, title, visual_prompt, color_palette, products, brand_fit_score), top_pick, and next_skill. Only JSON (no markdown).
EOF
)

run_stage "design" "$STAGE2_PROMPT" "$STAGE2_FILE"

TOP_CONCEPT=$(jq -r '.concepts[0]' "$STAGE2_FILE")
TOP_CONCEPT_TITLE=$(echo "$TOP_CONCEPT" | jq -r '.title')
TOP_CONCEPT_VISUAL=$(echo "$TOP_CONCEPT" | jq -r '.visual_prompt')

STAGE3_PROMPT=$(cat <<EOF
Using pod-pricing, calculate a recommended price for product "$PRODUCT" based on niche "$NICHE" and brand "$BRAND". Provide JSON output with product_type, recommended_price, margin_achieved, and breakdown. Do not add narration.
EOF
)

run_stage "pricing" "$STAGE3_PROMPT" "$STAGE3_FILE"

STAGE4_PROMPT=$(cat <<EOF
Create an Etsy listing via pod-listing-seo for niche "$NICHE" and brand "$BRAND". Use the top design titled "$TOP_CONCEPT_TITLE" with visual prompt "$TOP_CONCEPT_VISUAL" and use the pricing recommendation from stage3. Return JSON with title, tags, description, seo_score, and listing object. Only JSON.
EOF
)

run_stage "listing" "$STAGE4_PROMPT" "$STAGE4_FILE"

jq -n --argfile research "$STAGE1_FILE" --argfile design "$STAGE2_FILE" --argfile pricing "$STAGE3_FILE" --argfile listing "$STAGE4_FILE" \
  '{
    niche: $research.niche,
    timestamp: env.TIMESTAMP,
    research: $research,
    design: $design,
    pricing: $pricing,
    listing: $listing
  }' > "$REPORT_FILE"

log "Pipeline report saved: $REPORT_FILE"
CURRENT_STAGE="completed"