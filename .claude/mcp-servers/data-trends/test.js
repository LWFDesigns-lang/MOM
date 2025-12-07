#!/usr/bin/env node
// Test script for data-trends MCP server

import { spawn } from 'child_process';
import { createInterface } from 'readline';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const DEBUG = true;

function sendRequest(server, request) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Request timeout'));
    }, 10000);

    const handler = (line) => {
      try {
        const response = JSON.parse(line);
        clearTimeout(timeout);
        server.stdout.off('line', handler);
        resolve(response);
      } catch (err) {
        // Ignore parse errors, wait for valid JSON
      }
    };

    server.stdout.on('line', handler);
    server.stdin.write(JSON.stringify(request) + '\n');
  });
}

async function runTests() {
  console.log('Starting data-trends MCP server tests...\n');

  // Start the server
  const server = spawn(process.execPath, [join(__dirname, 'index.js')], {
    cwd: __dirname,
    env: { ...process.env, DEBUG_MCP: '0' }
  });

  const rl = createInterface({
    input: server.stdout,
    output: process.stdout,
    terminal: false
  });

  server.stdout = rl;

  server.stderr.on('data', (data) => {
    if (DEBUG) {
      console.error('Server stderr:', data.toString());
    }
  });

  try {
    // Test 1: Initialize
    console.log('Test 1: Initialize server');
    const initResponse = await sendRequest(server, {
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2024-11-05',
        capabilities: {},
        clientInfo: {
          name: 'test-client',
          version: '1.0.0'
        }
      }
    });
    console.log('Initialize response:', JSON.stringify(initResponse, null, 2));
    console.log('✓ Server initialized\n');

    // Test 2: List tools
    console.log('Test 2: List available tools');
    const listResponse = await sendRequest(server, {
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/list'
    });
    console.log('Tools:', JSON.stringify(listResponse.result.tools, null, 2));
    console.log('✓ Tools listed\n');

    // Test 3: Get trend stability for a sample keyword
    console.log('Test 3: Get trend stability for "pickleball"');
    const trendsResponse = await sendRequest(server, {
      jsonrpc: '2.0',
      id: 3,
      method: 'tools/call',
      params: {
        name: 'trends_get_stability',
        arguments: {
          keyword: 'pickleball',
          timeframe: '12mo'
        }
      }
    });
    console.log('Trends response:', JSON.stringify(trendsResponse, null, 2));
    
    if (trendsResponse.result?.content?.[0]?.text) {
      const result = JSON.parse(trendsResponse.result.content[0].text);
      console.log('✓ Trend stability retrieved:');
      console.log(`  - Stability Score: ${result.stability_score}`);
      console.log(`  - Trend Direction: ${result.trend_direction}`);
      console.log(`  - Average Interest: ${result.average_interest}`);
      console.log(`  - Current Interest: ${result.current_interest}`);
      console.log(`  - Data Points: ${result.data_points}`);
      console.log(`  - Source: ${result.source}`);
    }
    console.log();

    // Test 4: Test with different timeframe
    console.log('Test 4: Get trend stability for "pickleball" (6mo)');
    const trendsResponse2 = await sendRequest(server, {
      jsonrpc: '2.0',
      id: 4,
      method: 'tools/call',
      params: {
        name: 'trends_get_stability',
        arguments: {
          keyword: 'pickleball',
          timeframe: '6mo'
        }
      }
    });
    
    if (trendsResponse2.result?.content?.[0]?.text) {
      const result = JSON.parse(trendsResponse2.result.content[0].text);
      console.log('✓ 6-month trend retrieved:');
      console.log(`  - Source: ${result.source} (should be cache on second call)`);
      console.log(`  - Stability Score: ${result.stability_score}`);
    }
    console.log();

    console.log('All tests completed successfully! ✓');

  } catch (error) {
    console.error('Test failed:', error);
    process.exit(1);
  } finally {
    server.kill();
    process.exit(0);
  }
}

runTests();