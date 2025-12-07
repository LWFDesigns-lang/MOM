#!/usr/bin/env node
// Fallback executor for POD automation operations
// Handles MCP fallbacks, cache heuristics, and escalation logging.

const fs = require('fs');
const { spawn } = require('child_process');
const path = require('path');

const CONFIG_PATH = path.join(__dirname, '../config/fallbacks.json');
const LOG_DIR = path.join(__dirname, '../data/logs');
const FALLBACK_LOG = path.join(LOG_DIR, 'fallbacks.jsonl');

if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

const CONFIG = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
const GLOBAL_SETTINGS = CONFIG.global_settings || {};

async function executeWithFallback(operationName, params = {}) {
  const chain = CONFIG.fallback_chains[operationName];
  if (!chain) {
    throw new Error(`Unknown fallback operation: ${operationName}`);
  }

  const levels = ['primary', 'secondary', 'tertiary', 'quaternary', 'final'];
  let lastError = null;
  let penalty = 0;

  for (const level of levels) {
    const step = chain[level];
    if (!step) continue;

    try {
      const result = await executeStep(step, params);
      if (level !== 'primary' && chain[level].confidence_penalty) {
        penalty += chain[level].confidence_penalty;
        if (result.confidence != null) {
          result.confidence = Math.max(0.1, result.confidence - penalty);
          result._confidence_penalty = penalty;
        }
        result._fallback_level = level;
      }
      if (level !== 'primary' && GLOBAL_SETTINGS.log_fallbacks) {
        logFallback(operationName, level, params, result);
      }
      return result;
    } catch (error) {
      lastError = error;
      logWarning(operationName, level, error);
      if (GLOBAL_SETTINGS.max_retries && GLOBAL_SETTINGS.max_retries > 0) {
        await delay(GLOBAL_SETTINGS.retry_delay_ms || 1000);
      }
    }
  }

  throw new Error(`All fallbacks failed for ${operationName}: ${lastError?.message}`);
}

async function executeStep(step, params) {
  const type = step.type || 'mcp';
  switch (type) {
    case 'mcp':
      return await callMCP(step.mcp, step.tool, params, step.timeout_ms);
    case 'cache':
      return await checkCache(step.path, params, step.max_age_hours);
    case 'heuristic':
      return await runHeuristic(step.method, params);
    case 'local_script':
      return await runScript(step.script, params, step.timeout_ms || 3000);
    case 'escalate':
      return await escalateToQueue(step.queue, step.message, params);
    case 'default':
      return {
        value: step.value,
        warning: step.warning,
        _is_default: true,
      };
    default:
      throw new Error(`Unsupported step type: ${type}`);
  }
}

async function callMCP(serverName, toolName, params, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('MCP timeout')), timeout);
    // Placeholder - replace with actual Claude Code MCP client call.
    clearTimeout(timer);
    reject(new Error('MCP client not wired (fallback-executor standalone)'));
  });
}

async function checkCache(cachePath, params, maxAgeHours = 24) {
  if (!fs.existsSync(cachePath)) {
    throw new Error('Cache file missing');
  }
  const raw = fs.readFileSync(cachePath, 'utf8');
  const cache = JSON.parse(raw);
  const key = JSON.stringify(params);
  const entry = cache[key];
  if (!entry) throw new Error('Cache miss');
  const ageMs = Date.now() - new Date(entry.timestamp).getTime();
  if (ageMs > maxAgeHours * 3600 * 1000) {
    throw new Error('Cache expired');
  }
  return { ...entry.data, _from_cache: true, _cache_age_hours: ageMs / 3600000 };
}

async function runHeuristic(method, params) {
  const heuristics = {
    estimate_from_keywords: (p) => {
      const niche = (p.niche || '').toLowerCase();
      let estimate = 25000;
      if (niche.includes('generic') || niche.includes('funny')) estimate = 150000;
      if (niche.includes('unique') || niche.includes('niche')) estimate = 10000;
      return { estimate };
    },
    estimate_from_seasonality: (p) => {
      const seasons = {
        christmas: 70,
        halloween: 65,
        spring: 55,
        summer: 60,
      };
      const term = (p.niche || '').toLowerCase();
      const value = Object.entries(seasons).find(([k]) => term.includes(k));
      return {
        score_12mo: value ? value[1] : 50,
        trend_direction: 'stable',
        _is_estimate: true,
      };
    },
  };

  const heuristic = heuristics[method];
  if (!heuristic) {
    throw new Error(`Unknown heuristic method: ${method}`);
  }
  return heuristic(params);
}

async function runScript(scriptPath, params, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const args = Object.values(params).map(String);
    const proc = spawn('node', [scriptPath, ...args], { stdio: ['ignore', 'pipe', 'pipe'] });

    let output = '';
    let errorOutput = '';

    const timer = setTimeout(() => {
      proc.kill();
      reject(new Error('Script timeout'));
    }, timeoutMs);

    proc.stdout.on('data', (chunk) => (output += chunk));
    proc.stderr.on('data', (chunk) => (errorOutput += chunk));

    proc.on('close', (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        return reject(new Error(`Script exited ${code}: ${errorOutput}`));
      }
      try {
        const parsed = JSON.parse(output);
        resolve(parsed);
      } catch (err) {
        reject(new Error(`Invalid JSON from script: ${err.message}`));
      }
    });
  });
}

async function escalateToQueue(queuePath, message, params) {
  const rendered = message.replace(/\{\{(\w+)\}\}/g, (_, key) => params[key] || '');
  const entry = {
    timestamp: new Date().toISOString(),
    message: rendered,
    params,
    status: 'pending',
  };
  fs.appendFileSync(queuePath, JSON.stringify(entry) + '\n');
  return entry;
}

function logFallback(operation, level, params, result) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    operation,
    level,
    params,
    result_summary: {
      confidence: result.confidence,
      fallback: level,
      from_cache: result._from_cache,
      is_estimate: result._is_estimate,
    },
  };
  fs.appendFileSync(FALLBACK_LOG, JSON.stringify(logEntry) + '\n');
}

function logWarning(operation, level, error) {
  if (GLOBAL_SETTINGS.log_fallbacks) {
    const warning = {
      timestamp: new Date().toISOString(),
      operation,
      level,
      error: error.message,
    };
    fs.appendFileSync(FALLBACK_LOG, JSON.stringify(warning) + '\n');
  }
}

function delay(ms = 1000) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = { executeWithFallback };