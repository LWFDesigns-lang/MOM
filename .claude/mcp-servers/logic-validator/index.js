#!/usr/bin/env node
/**
 * Logic Validator MCP Server
 *
 * Exposes POD business logic tools through the Model Context Protocol (MCP) 2.0.
 * Uses stdio transport for JSON-RPC communication with Claude Desktop.
 *
 * MCP 2.0 Compliance:
 * - Protocol version: 2024-11-05 (MCP 2.0)
 * - Capabilities: tools (no resources or prompts)
 * - Transport: stdio with JSON-RPC 2.0
 * - Error handling: Enhanced with debug logging support
 *
 * Available Tools:
 * - validate_niche: Validate POD niche viability
 * - calculate_price: Calculate product pricing
 * - read_brand_voice: Read brand style guide
 * - save_to_history: Persist research results
 * - read_history: Retrieve past research
 *
 * Debug Mode:
 * Set DEBUG_MCP=1 environment variable to enable detailed logging to stderr
 */

import { createInterface } from 'readline';
import { spawn } from 'child_process';
import { readFile, writeFile } from 'fs/promises';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Paths relative to workspace root (3 levels up from this file)
const WORKSPACE_ROOT = resolve(__dirname, '../../..');
const VALIDATE_SCRIPT = resolve(WORKSPACE_ROOT, '.claude/skills/pod-research/scripts/validate.py');
const PRICING_SCRIPT = resolve(WORKSPACE_ROOT, '.claude/skills/pod-pricing/scripts/pricing.py');
const STYLE_GUIDE = resolve(WORKSPACE_ROOT, '.claude/skills/pod-design-review/prompts/style-guide.md');
const HISTORY_FILE = resolve(WORKSPACE_ROOT, '.claude/memories/history.json');

// MCP Server Info
// Protocol version 2024-11-05 is the MCP 2.0 specification
const SERVER_INFO = {
  name: 'logic-validator',
  version: '1.0.0',
  protocolVersion: '2024-11-05' // MCP 2.0
};

// Debug logging configuration
const DEBUG = process.env.DEBUG_MCP === '1';

/**
 * Log debug messages to stderr when DEBUG mode is enabled
 */
function debugLog(...args) {
  if (DEBUG) {
    console.error('[DEBUG logic-validator]', ...args);
  }
}

/**
 * Log errors to stderr (always enabled)
 */
function errorLog(...args) {
  console.error('[ERROR logic-validator]', ...args);
}

// Tool Definitions
const TOOLS = [
  {
    name: 'validate_niche',
    description: 'Validates a potential POD niche by analyzing market metrics against business viability thresholds. Returns GO/SKIP recommendation with confidence level and specific concerns.',
    inputSchema: {
      type: 'object',
      properties: {
        niche: {
          type: 'string',
          description: 'The niche name to validate (e.g., \'pickleball\', \'cottagecore\')'
        },
        etsy_count: {
          type: 'integer',
          description: 'Number of active Etsy listings for this niche'
        },
        trend_score: {
          type: 'number',
          minimum: 0,
          maximum: 1,
          description: 'Google Trends normalized score (0-1)'
        }
      },
      required: ['niche', 'etsy_count', 'trend_score']
    }
  },
  {
    name: 'calculate_price',
    description: 'Calculates recommended pricing for a POD product including cost breakdown, profit margins, and minimum viable price.',
    inputSchema: {
      type: 'object',
      properties: {
        product_type: {
          type: 'string',
          enum: ['t-shirt', 'hoodie', 'mug', 'poster', 'sticker', 'tote-bag'],
          description: 'The product type to calculate pricing for'
        }
      },
      required: ['product_type']
    }
  },
  {
    name: 'read_brand_voice',
    description: 'Retrieves the style guide and brand voice documentation for generating on-brand design concepts.',
    inputSchema: {
      type: 'object',
      properties: {
        brand: {
          type: 'string',
          default: 'lwf',
          description: 'Brand identifier (default: \'lwf\')'
        }
      },
      required: []
    }
  },
  {
    name: 'save_to_history',
    description: 'Persists the results of a research and validation run to local history for future reference.',
    inputSchema: {
      type: 'object',
      properties: {
        data: {
          type: 'object',
          description: 'Complete analysis data to save',
          properties: {
            niche: { type: 'string' },
            validation_result: { type: 'object' },
            pricing: { type: 'object' },
            design_concept: { type: 'string' },
            timestamp: { type: 'string' }
          },
          required: ['niche']
        }
      },
      required: ['data']
    }
  },
  {
    name: 'read_history',
    description: 'Retrieves previous research runs from history to inform current decisions and avoid duplicate work.',
    inputSchema: {
      type: 'object',
      properties: {
        niche_filter: {
          type: 'string',
          description: 'Optional filter to match niche names (case-insensitive substring match)'
        },
        limit: {
          type: 'integer',
          default: 10,
          description: 'Maximum number of entries to return'
        }
      },
      required: []
    }
  }
];

/**
 * Execute a Python script and return parsed JSON output
 */
async function executePython(scriptPath, args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python', [scriptPath, JSON.stringify(args)]);
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    proc.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Script exited with code ${code}: ${stderr || stdout}`));
      } else {
        try {
          const result = JSON.parse(stdout);
          resolve(result);
        } catch (err) {
          reject(new Error(`Invalid JSON output: ${stdout}`));
        }
      }
    });

    proc.on('error', (err) => {
      reject(new Error(`Failed to spawn python: ${err.message}`));
    });
  });
}

/**
 * Load history from file, create empty array if not exists
 */
async function loadHistory() {
  try {
    const data = await readFile(HISTORY_FILE, 'utf8');
    return JSON.parse(data);
  } catch (err) {
    // File doesn't exist or is invalid, return empty array
    return [];
  }
}

/**
 * Save history to file atomically
 */
async function saveHistory(entries) {
  await writeFile(HISTORY_FILE, JSON.stringify(entries, null, 2), 'utf8');
}

/**
 * Tool execution handlers
 */
const toolHandlers = {
  async validate_niche(args) {
    try {
      const result = await executePython(VALIDATE_SCRIPT, {
        niche: args.niche,
        etsy_count: args.etsy_count,
        trend_score: args.trend_score
      });
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(result, null, 2)
          }
        ]
      };
    } catch (err) {
      throw new Error(`Niche validation failed: ${err.message}`);
    }
  },

  async calculate_price(args) {
    try {
      const result = await executePython(PRICING_SCRIPT, {
        product_type: args.product_type
      });
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(result, null, 2)
          }
        ]
      };
    } catch (err) {
      throw new Error(`Price calculation failed: ${err.message}`);
    }
  },

  async read_brand_voice(args) {
    try {
      const content = await readFile(STYLE_GUIDE, 'utf8');
      return {
        content: [
          {
            type: 'text',
            text: content
          }
        ]
      };
    } catch (err) {
      throw new Error(`Failed to read style guide: ${err.message}`);
    }
  },

  async save_to_history(args) {
    try {
      const history = await loadHistory();
      
      // Add timestamp if not provided
      const entry = {
        ...args.data,
        timestamp: args.data.timestamp || new Date().toISOString()
      };
      
      // Append to history
      history.push(entry);
      
      // Save atomically
      await saveHistory(history);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              message: `Saved entry for niche: ${entry.niche}`,
              timestamp: entry.timestamp,
              total_entries: history.length
            }, null, 2)
          }
        ]
      };
    } catch (err) {
      throw new Error(`Failed to save to history: ${err.message}`);
    }
  },

  async read_history(args) {
    try {
      let history = await loadHistory();
      
      // Apply niche filter if provided
      if (args.niche_filter) {
        const filter = args.niche_filter.toLowerCase();
        history = history.filter(entry => 
          entry.niche && entry.niche.toLowerCase().includes(filter)
        );
      }
      
      // Sort by timestamp descending (most recent first)
      history.sort((a, b) => {
        const timeA = new Date(a.timestamp || 0);
        const timeB = new Date(b.timestamp || 0);
        return timeB - timeA;
      });
      
      // Apply limit
      const limit = args.limit || 10;
      const results = history.slice(0, limit);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              total_found: history.length,
              returned: results.length,
              entries: results
            }, null, 2)
          }
        ]
      };
    } catch (err) {
      throw new Error(`Failed to read history: ${err.message}`);
    }
  }
};

/**
 * Handle incoming JSON-RPC requests
 */
async function handleRequest(request) {
  const { id, method, params } = request;

  // Log incoming method for debugging
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
            // MCP 2.0 capabilities - this server only provides tools
            // Resources and prompts capabilities are not included as they are not supported
            capabilities: {
              tools: {} // Server supports tool listing and execution
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
    // Log error to stderr (not stdout which is for JSON-RPC protocol)
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
 * Main server loop - read from stdin, write to stdout
 * Implements MCP stdio transport with JSON-RPC 2.0 message handling
 */
function main() {
  // Log server startup
  debugLog('Starting Logic Validator MCP Server');
  debugLog(`Protocol version: ${SERVER_INFO.protocolVersion}`);
  debugLog(`Server version: ${SERVER_INFO.version}`);
  debugLog(`Debug mode: ${DEBUG ? 'enabled' : 'disabled'}`);

  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  rl.on('line', async (line) => {
    try {
      // Parse JSON-RPC request
      const request = JSON.parse(line);
      
      // Handle the request
      const response = await handleRequest(request);
      
      // Send response via stdout (MCP stdio transport)
      console.log(JSON.stringify(response));
      
    } catch (err) {
      // Enhanced error handling for parse failures
      errorLog('Failed to parse or handle request:', err.message);
      
      if (DEBUG) {
        errorLog('Raw line:', line);
        errorLog('Parse error:', err.stack);
      }
      
      // Attempt to send error response if we can extract an ID
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
        // Can't even parse the ID - log to stderr only
        errorLog('Cannot recover from parse error - unable to extract request ID');
      }
    }
  });

  rl.on('close', () => {
    debugLog('stdin closed, shutting down server');
    process.exit(0);
  });

  // Handle process errors
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
