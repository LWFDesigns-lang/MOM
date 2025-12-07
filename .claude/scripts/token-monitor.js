#!/usr/bin/env node
// Token monitor helper used by workflows and hooks.
// Tracks usage, enforces budgets, logs results.

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const WORKFLOW_CONFIG = path.join(__dirname, '../config/token-budgets.yaml');
const LOG_DIR = path.join(__dirname, '../data/logs');

if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

let BUDGETS = {};
try {
  const yamlContent = fs.readFileSync(WORKFLOW_CONFIG, 'utf8');
  const parsed = yaml.load(yamlContent);
  BUDGETS = parsed.workflows || {};
} catch (err) {
  console.error(`token-monitor: failed to load budgets (${err.message})`);
}

const state = {
  sessionTokens: 0,
  workflowTokens: {},
};

function _getTodayLogPath() {
  const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  return path.join(LOG_DIR, `tokens_${today}.json`);
}

function _persistLog() {
  const payload = {
    timestamp: new Date().toISOString(),
    session_total: state.sessionTokens,
    by_workflow: state.workflowTokens,
  };
  fs.writeFileSync(_getTodayLogPath(), JSON.stringify(payload, null, 2), 'utf8');
}

function track(workflow, tokens) {
  state.sessionTokens += tokens;
  state.workflowTokens[workflow] = (state.workflowTokens[workflow] || 0) + tokens;
  _persistLog();

  const budget = BUDGETS[workflow];
  if (budget) {
    if (state.workflowTokens[workflow] > budget.budget) {
      console.error(
        `🔴 BUDGET EXCEEDED: ${workflow} used ${state.workflowTokens[workflow]}/${budget.budget}`
      );
      return { status: 'exceeded', action: 'stop_workflow' };
    }
    if (state.workflowTokens[workflow] > budget.warning) {
      console.warn(
        `⚠️ WARNING: ${workflow} at ${state.workflowTokens[workflow]}/${budget.budget}`
      );
      return { status: 'warning', action: 'continue_with_caution' };
    }
  }

  return { status: 'ok', tokens_used: state.workflowTokens[workflow] };
}

function getUsageReport() {
  return {
    session_total: state.sessionTokens,
    by_workflow: state.workflowTokens,
    timestamp: new Date().toISOString(),
  };
}

function resetWorkflow(workflow) {
  state.workflowTokens[workflow] = 0;
  _persistLog();
}

function resetSession() {
  state.sessionTokens = 0;
  state.workflowTokens = {};
  _persistLog();
}

module.exports = { track, getUsageReport, resetWorkflow, resetSession };