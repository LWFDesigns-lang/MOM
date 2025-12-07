#!/usr/bin/env node
// data-trends MCP server for trend data retrieval with hybrid approach

import { createInterface } from 'readline';
import googleTrends from 'google-trends-api';
import NodeCache from 'node-cache';

// Debug logging configuration
const DEBUG = process.env.DEBUG_MCP === '1';
const debugLog = (...args) => DEBUG && console.error('[data-trends DEBUG]', ...args);
const errorLog = (...args) => console.error('[data-trends ERROR]', ...args);

// API configuration
const SERPAPI_KEY = process.env.SERPAPI_KEY;
const DATAFORSEO_LOGIN = process.env.DATAFORSEO_LOGIN;
const DATAFORSEO_PASSWORD = process.env.DATAFORSEO_PASSWORD;

// Cache setup - 24 hour TTL
const cache = new NodeCache({ stdTTL: 86400 });

// MCP Server Info
const SERVER_INFO = {
  name: 'data-trends',
  version: '1.0.0',
  protocolVersion: '2024-11-05' // MCP 2.0
};

// Tool Definitions
const TOOLS = [
  {
    name: 'trends_get_stability',
    description: 'Get trend stability score for a keyword with configurable timeframe',
    inputSchema: {
      type: 'object',
      properties: {
        keyword: { type: 'string', description: 'The niche keyword to analyze' },
        timeframe: { 
          type: 'string', 
          description: 'Timeframe for analysis',
          enum: ['3mo', '6mo', '12mo'],
          default: '12mo'
        }
      },
      required: ['keyword']
    }
  }
];

/**
 * Sleep utility for retry backoff
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Calculate stability score from trend data
 * Lower coefficient of variation = higher stability
 */
function calculateStability(trendData) {
  if (!trendData || trendData.length === 0) {
    return 0.5; // Default medium stability
  }

  const values = trendData.map(d => d.value);
  
  // Calculate mean
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  
  // Calculate variance and standard deviation
  const variance = values.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / values.length;
  const stdDev = Math.sqrt(variance);
  
  // Calculate coefficient of variation
  const cv = mean > 0 ? stdDev / mean : 1;
  
  // Convert to 0-1 stability score (lower CV = higher stability)
  // CV of 0 = perfect stability (1.0), CV of 1+ = low stability (0)
  return Math.max(0, Math.min(1, 1 - cv));
}

/**
 * Detect trend direction by comparing first half to second half
 */
function detectTrendDirection(trendData) {
  if (!trendData || trendData.length < 2) {
    return 'stable';
  }

  const mid = Math.floor(trendData.length / 2);
  const firstHalf = trendData.slice(0, mid);
  const secondHalf = trendData.slice(mid);
  
  const firstAvg = firstHalf.reduce((a, b) => a + b.value, 0) / firstHalf.length;
  const secondAvg = secondHalf.reduce((a, b) => a + b.value, 0) / secondHalf.length;
  
  const changePercent = (secondAvg - firstAvg) / firstAvg;
  
  if (changePercent > 0.15) return 'rising';
  if (changePercent < -0.15) return 'declining';
  return 'stable';
}

/**
 * Fetch trend data from google-trends-api
 */
async function fetchFromGoogleTrendsApi(keyword, timeframe = '12mo') {
  const startTime = {
    '3mo': 90 * 24 * 60 * 60 * 1000,
    '6mo': 180 * 24 * 60 * 60 * 1000,
    '12mo': 365 * 24 * 60 * 60 * 1000
  }[timeframe];

  debugLog(`Fetching trends for "${keyword}" with timeframe ${timeframe}`);

  const result = await googleTrends.interestOverTime({
    keyword,
    startTime: new Date(Date.now() - startTime),
    geo: 'US'
  });
  
  const parsed = JSON.parse(result);
  debugLog('Google Trends raw response:', JSON.stringify(parsed, null, 2));
  
  return parsed;
}

/**
 * Process raw Google Trends data into our format
 */
function processGoogleTrendsData(rawData, keyword, timeframe, source) {
  if (!rawData || !rawData.default || !rawData.default.timelineData) {
    throw new Error('Invalid Google Trends response format');
  }

  const timelineData = rawData.default.timelineData;
  
  // Extract values from timeline data
  const trendData = timelineData.map(item => ({
    value: item.value[0]
  }));

  const values = trendData.map(d => d.value);
  const stabilityScore = calculateStability(trendData);
  const trendDirection = detectTrendDirection(trendData);
  const averageInterest = values.reduce((a, b) => a + b, 0) / values.length;
  const currentInterest = values[values.length - 1];

  return {
    keyword,
    stability_score: Math.round(stabilityScore * 100) / 100, // Round to 2 decimals
    trend_direction: trendDirection,
    average_interest: Math.round(averageInterest),
    current_interest: currentInterest,
    data_points: trendData.length,
    source,
    timestamp: new Date().toISOString()
  };
}

/**
 * Get trend data with fallback strategy
 */
async function getTrendDataWithFallback(keyword, timeframe = '12mo') {
  // Check cache first
  const cacheKey = `trend:${keyword}:${timeframe}`;
  const cached = cache.get(cacheKey);
  if (cached) {
    debugLog('Returning cached result for:', cacheKey);
    return { ...cached, source: 'cache' };
  }
  
  // Try google-trends-api with retry
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      debugLog(`Attempting google-trends-api (attempt ${attempt + 1}/3)`);
      const rawData = await fetchFromGoogleTrendsApi(keyword, timeframe);
      const result = processGoogleTrendsData(rawData, keyword, timeframe, 'google-trends-api');
      
      // Cache the successful result
      cache.set(cacheKey, result);
      debugLog('Successfully fetched and cached trend data');
      
      return result;
    } catch (err) {
      errorLog(`google-trends-api attempt ${attempt + 1} failed:`, err.message);
      
      // Check if it's a rate limit error
      if (err.message.includes('429') && attempt < 2) {
        const backoffTime = Math.pow(2, attempt) * 5000; // 5s, 10s, 20s
        debugLog(`Rate limited, backing off for ${backoffTime}ms`);
        await sleep(backoffTime);
        continue;
      }
      
      // If this was the last attempt, break to fallback
      if (attempt === 2) {
        errorLog('All google-trends-api attempts failed');
        break;
      }
    }
  }
  
  // Fallback: Return synthetic low-confidence result
  // (SerpAPI/DataForSEO would require API keys we may not have configured)
  debugLog('Using fallback synthetic data');
  
  const fallbackResult = {
    keyword,
    stability_score: 0.5,
    trend_direction: 'stable',
    average_interest: 50,
    current_interest: 50,
    data_points: 0,
    source: 'fallback',
    error: 'Unable to fetch trend data, using default values',
    timestamp: new Date().toISOString()
  };
  
  return fallbackResult;
}

/**
 * Tool execution handlers
 */
const toolHandlers = {
  async trends_get_stability(args) {
    try {
      const keyword = args.keyword;
      const timeframe = args.timeframe || '12mo';
      
      debugLog('Tool called:', 'trends_get_stability', 'with args:', JSON.stringify(args));
      
      // Validate timeframe
      if (!['3mo', '6mo', '12mo'].includes(timeframe)) {
        throw new Error('Invalid timeframe. Must be one of: 3mo, 6mo, 12mo');
      }
      
      const result = await getTrendDataWithFallback(keyword, timeframe);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(result, null, 2)
          }
        ]
      };
    } catch (err) {
      errorLog('Error in trends_get_stability:', err.message);
      
      // Return error result
      const errorResult = {
        keyword: args.keyword,
        stability_score: 0.5,
        trend_direction: 'stable',
        average_interest: 50,
        current_interest: 50,
        data_points: 0,
        source: 'error',
        error: err.message,
        timestamp: new Date().toISOString()
      };
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(errorResult, null, 2)
          }
        ]
      };
    }
  }
};

/**
 * Handle incoming JSON-RPC requests
 */
async function handleRequest(request) {
  const { id, method, params } = request;

  debugLog(`Received method: ${method}`, params ? `with params` : 'without params');

  try {
    switch (method) {
      case 'initialize':
        debugLog('Initializing server with MCP 2.0 protocol');
        return {
          jsonrpc: '2.0',
          id,
          result: {
            protocolVersion: SERVER_INFO.protocolVersion,
            capabilities: {
              tools: {}
            },
            serverInfo: {
              name: SERVER_INFO.name,
              version: SERVER_INFO.version
            }
          }
        };

      case 'tools/list':
        return {
          jsonrpc: '2.0',
          id,
          result: {
            tools: TOOLS
          }
        };

      case 'tools/call':
        const toolName = params.name;
        const toolArgs = params.arguments || {};
        
        if (!toolHandlers[toolName]) {
          throw new Error(`Unknown tool: ${toolName}`);
        }
        
        const result = await toolHandlers[toolName](toolArgs);
        
        return {
          jsonrpc: '2.0',
          id,
          result
        };

      default:
        throw new Error(`Unknown method: ${method}`);
    }
  } catch (error) {
    errorLog(`Error handling method '${method}':`, error.message);
    if (DEBUG && error.stack) {
      errorLog('Stack trace:', error.stack);
    }
    
    return {
      jsonrpc: '2.0',
      id,
      error: {
        code: -32000,
        message: error.message || 'Unknown error occurred',
        data: DEBUG ? { method, params } : undefined
      }
    };
  }
}

/**
 * Main server loop
 */
function main() {
  debugLog('Starting data-trends MCP Server');
  debugLog(`Protocol version: ${SERVER_INFO.protocolVersion}`);
  debugLog(`Server version: ${SERVER_INFO.version}`);
  debugLog(`Debug mode: ${DEBUG ? 'enabled' : 'disabled'}`);
  debugLog(`Cache TTL: 24 hours`);

  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  rl.on('line', async (line) => {
    try {
      const request = JSON.parse(line);
      const response = await handleRequest(request);
      console.log(JSON.stringify(response));
    } catch (err) {
      errorLog('Failed to parse or handle request:', err.message);
      
      if (DEBUG) {
        errorLog('Raw line:', line);
        errorLog('Parse error:', err.stack);
      }
      
      try {
        const partialRequest = JSON.parse(line);
        console.log(JSON.stringify({
          jsonrpc: '2.0',
          id: partialRequest.id || null,
          error: {
            code: -32700,
            message: 'Parse error',
            data: DEBUG ? { error: err.message } : undefined
          }
        }));
      } catch (parseErr) {
        errorLog('Cannot recover from parse error - unable to extract request ID');
      }
    }
  });

  rl.on('close', () => {
    debugLog('stdin closed, shutting down server');
    process.exit(0);
  });

  process.on('uncaughtException', (err) => {
    errorLog('Uncaught exception:', err.message);
    if (DEBUG) {
      errorLog('Stack trace:', err.stack);
    }
    process.exit(1);
  });

  process.on('unhandledRejection', (reason, promise) => {
    errorLog('Unhandled promise rejection:', reason);
    if (DEBUG) {
      errorLog('Promise:', promise);
    }
  });
}

// Start the server
main();
