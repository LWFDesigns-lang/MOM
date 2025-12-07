#!/usr/bin/env node
// data-etsy MCP server v2.0 - Tiered data extraction system
// Implements 4-tier fallback: Etsy API -> Serper -> Perplexity -> Brave

import { config } from 'dotenv';
import { createInterface } from 'readline';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

// Get directory paths
const __dirname = dirname(fileURLToPath(import.meta.url));
const workspaceRoot = resolve(__dirname, '../../..');

// Load .env from workspace root
config({ path: resolve(workspaceRoot, '.env') });

// Import data sources and utilities
import { ListingCountCache } from './lib/cache.js';
import { EtsyApiClient } from './lib/data-sources/etsy-api.js';
import { SerperClient } from './lib/data-sources/serper.js';
import { PerplexityClient } from './lib/data-sources/perplexity.js';
import { BraveClient } from './lib/data-sources/brave.js';


// Debug logging configuration
const DEBUG = process.env.DEBUG_MCP === '1';
const debugLog = (...args) => DEBUG && console.error('[data-etsy DEBUG]', ...args);
const errorLog = (...args) => console.error('[data-etsy ERROR]', ...args);

// MCP Server Info
const SERVER_INFO = {
  name: 'data-etsy',
  version: '2.0.0',
  protocolVersion: '2024-11-05' // MCP 2.0
};

// Tool Definitions
const TOOLS = [
  {
    name: 'etsy_search_listings',
    description: 'Search Etsy listings by keyword',
    inputSchema: {
      type: 'object',
      properties: {
        keyword: { type: 'string', description: 'Keyword to search for' },
        limit: { type: 'number', description: 'Result limit', default: 10 }
      },
      required: ['keyword']
    }
  },
  {
    name: 'etsy_get_listing_count',
    description: 'Get total listing count for keyword using 4-tier system: Etsy API -> Serper -> Perplexity -> Brave',
    inputSchema: {
      type: 'object',
      properties: {
        keyword: { type: 'string', description: 'Keyword to count listings for' }
      },
      required: ['keyword']
    }
  }
];

// Initialize data sources and cache
let cache;
let etsyApi;
let serper;
let perplexity;
let brave;

/**
 * Initialize all data sources and cache
 */
async function initializeDataSources() {
  debugLog('Initializing data sources...');
  
  // Initialize cache
  cache = new ListingCountCache({
    cacheFile: resolve(workspaceRoot, '.cache/etsy-listing-counts.json')
  });
  await cache.initialize();
  debugLog('Cache initialized');
  
  // Initialize Tier 1: Etsy API
  etsyApi = new EtsyApiClient();
  debugLog('Etsy API configured:', etsyApi.isConfigured());
  
  // Initialize Tier 2: Serper
  serper = new SerperClient();
  debugLog('Serper configured:', serper.isConfigured());
  
  // Initialize Tier 3: Perplexity
  perplexity = new PerplexityClient();
  debugLog('Perplexity configured:', perplexity.isConfigured());
  
  // Initialize Tier 4: Brave
  brave = new BraveClient();
  debugLog('Brave configured:', brave.isConfigured());
}

/**
 * Get listing count using tiered fallback system
 * @param {string} keyword - Search keyword
 * @returns {Promise<Object>} Result with count, source, confidence
 */
async function getListingCount(keyword) {
  debugLog(`Getting listing count for: ${keyword}`);
  
  // Check cache first
  const cached = await cache.get(keyword);
  if (cached) {
    debugLog(`Cache hit for: ${keyword}`);
    return {
      keyword,
      count: cached.count,
      source: 'cache',
      confidence: cached.confidence,
      cached: true,
      timestamp: cached.createdAt
    };
  }
  
  debugLog(`Cache miss for: ${keyword}, trying data sources...`);
  
  // Tier 1: Etsy API (FREE, 100% accurate)
  if (etsyApi.isConfigured()) {
    const cbState = etsyApi.circuitBreaker.isOpen();
    if (cbState) {
      try {
        debugLog('Trying Tier 1: Etsy API');
        const result = await etsyApi.getListingCount(keyword);
        await cache.set(keyword, result);
        return { ...result, cached: false };
      } catch (error) {
        debugLog('Etsy API failed:', error.message);
      }
    } else {
      debugLog('Etsy API skipped (circuit breaker blocking)');
    }
  } else {
    debugLog('Etsy API skipped (not configured)');
  }
  
  // Tier 2: Serper (CHEAP paid - $0.0003/query, 95% accurate)
  if (serper.isConfigured()) {
    const cbState = serper.circuitBreaker.isOpen();
    if (cbState) {
      try {
        debugLog('Trying Tier 2: Serper');
        const result = await serper.getListingCount(keyword);
        await cache.set(keyword, result);
        return { ...result, cached: false };
      } catch (error) {
        debugLog('Serper failed:', error.message);
      }
    } else {
      debugLog('Serper skipped (circuit breaker blocking)');
    }
  } else {
    debugLog('Serper skipped (not configured)');
  }
  
  // Tier 3: Perplexity (~$0.001/query, 60-70% accurate)
  if (perplexity.isConfigured()) {
    const cbState = perplexity.circuitBreaker.isOpen();
    if (cbState) {
      try {
        debugLog('Trying Tier 3: Perplexity');
        const result = await perplexity.getListingCount(keyword);
        await cache.set(keyword, result, { ttl: 1 * 60 * 60 * 1000 }); // 1 hour for estimates
        return { ...result, cached: false };
      } catch (error) {
        debugLog('Perplexity failed:', error.message);
      }
    } else {
      debugLog('Perplexity skipped (circuit breaker blocking)');
    }
  } else {
    debugLog('Perplexity skipped (not configured)');
  }
  
  // Tier 4: Brave Search (FREE, ~33% accurate - last resort)
  if (brave.isConfigured()) {
    const cbState = brave.circuitBreaker.isOpen();
    if (cbState) {
      try {
        debugLog('Trying Tier 4: Brave Search (last resort)');
        const result = await brave.getListingCount(keyword);
        await cache.set(keyword, result, { ttl: 30 * 60 * 1000 }); // 30 min for low confidence
        return { ...result, cached: false };
      } catch (error) {
        debugLog('Brave Search failed:', error.message);
      }
    } else {
      debugLog('Brave Search skipped (circuit breaker blocking)');
    }
  } else {
    debugLog('Brave Search skipped (not configured)');
  }
  
  // All sources failed
  errorLog('All data sources failed for keyword:', keyword);
  return {
    keyword,
    count: -1,
    source: 'fallback',
    confidence: 'none',
    cached: false,
    timestamp: new Date().toISOString(),
    error: 'All data sources failed or unavailable'
  };
}

/**
 * Tool execution handlers
 */
const toolHandlers = {
  async etsy_search_listings(args) {
    try {
      debugLog('Tool called:', 'etsy_search_listings', 'with args:', JSON.stringify(args));
      // TODO: integrate Etsy API search functionality
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({ 
              listings: [], 
              count: 0, 
              keyword: args.keyword, 
              limit: args.limit || 10, 
              note: 'Search functionality not yet implemented - use etsy_get_listing_count for counts' 
            }, null, 2)
          }
        ]
      };
    } catch (err) {
      throw new Error(`Etsy search failed: ${err.message}`);
    }
  },

  async etsy_get_listing_count(args) {
    try {
      debugLog('Tool called:', 'etsy_get_listing_count', 'with args:', JSON.stringify(args));
      
      const result = await getListingCount(args.keyword);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(result, null, 2)
          }
        ]
      };
    } catch (err) {
      errorLog('Error in etsy_get_listing_count:', err.message);
      
      // Return error result
      const errorResult = {
        keyword: args.keyword,
        count: -1,
        source: 'error',
        confidence: 'none',
        cached: false,
        timestamp: new Date().toISOString(),
        error: err.message
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
async function main() {
  debugLog('Starting data-etsy MCP Server v2.0');
  debugLog(`Protocol version: ${SERVER_INFO.protocolVersion}`);
  debugLog(`Server version: ${SERVER_INFO.version}`);
  debugLog(`Debug mode: ${DEBUG ? 'enabled' : 'disabled'}`);
  debugLog(`Workspace root: ${workspaceRoot}`);

  // Initialize data sources
  await initializeDataSources();

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

  rl.on('close', async () => {
    debugLog('stdin closed, shutting down server');
    if (cache) {
      await cache.shutdown();
    }
    process.exit(0);
  });

  process.on('uncaughtException', async (err) => {
    errorLog('Uncaught exception:', err.message);
    if (DEBUG) {
      errorLog('Stack trace:', err.stack);
    }
    if (cache) {
      await cache.shutdown();
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
