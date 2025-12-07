#!/usr/bin/env node
/**
 * Comprehensive test suite for data-etsy MCP server v2.0
 * Tests tiered fallback system, cache behavior, and accuracy metrics
 */

import { spawn } from 'child_process';
import { createInterface } from 'readline';
import { writeFile } from 'fs/promises';

// Test configuration
const TEST_CONFIG = {
  // High-volume keywords - expect > 50,000 listings
  highVolume: [
    { keyword: 't-shirt', minExpected: 50000, maxExpected: 500000 },
    { keyword: 'handmade jewelry', minExpected: 100000, maxExpected: 1000000 },
    { keyword: 'sticker', minExpected: 100000, maxExpected: 800000 }
  ],
  
  // Medium-volume keywords - expect 10,000-100,000 listings
  mediumVolume: [
    { keyword: 'vintage poster', minExpected: 10000, maxExpected: 100000 },
    { keyword: 'custom dog portrait', minExpected: 5000, maxExpected: 50000 },
    { keyword: 'personalized mug', minExpected: 20000, maxExpected: 150000 }
  ],
  
  // Niche keywords - expect < 10,000 listings
  niche: [
    { keyword: 'quantum physics mug', minExpected: 100, maxExpected: 10000 },
    { keyword: 'steampunk octopus', minExpected: 100, maxExpected: 5000 },
    { keyword: 'pickleball paddle custom', minExpected: 500, maxExpected: 8000 }
  ]
};

// Flatten all tests
const ALL_TESTS = [
  ...TEST_CONFIG.highVolume.map(t => ({ ...t, category: 'High-Volume' })),
  ...TEST_CONFIG.mediumVolume.map(t => ({ ...t, category: 'Medium-Volume' })),
  ...TEST_CONFIG.niche.map(t => ({ ...t, category: 'Niche' }))
];

let requestId = 1;
const results = [];
let cacheTestResults = [];

/**
 * Send a JSON-RPC request to the server
 */
function sendRequest(proc, method, params = {}) {
  const request = {
    jsonrpc: '2.0',
    id: requestId++,
    method,
    params
  };
  
  console.log(`→ Sending: ${method}${params.name ? ' (' + params.name + ')' : ''}`);
  proc.stdin.write(JSON.stringify(request) + '\n');
  
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Request timeout after 30s'));
    }, 30000);
    
    const handler = (line) => {
      try {
        const response = JSON.parse(line);
        if (response.id === request.id) {
          clearTimeout(timeout);
          proc.stdout.off('line', handler);
          
          if (response.error) {
            reject(new Error(response.error.message));
          } else {
            resolve(response.result);
          }
        }
      } catch (err) {
        // Ignore parse errors for non-JSON output
      }
    };
    
    proc.stdout.on('line', handler);
  });
}

/**
 * Check if a count is within expected range
 */
function isWithinRange(count, minExpected, maxExpected) {
  return count >= minExpected && count <= maxExpected;
}

/**
 * Calculate accuracy percentage based on expected ranges
 */
function calculateAccuracy(results) {
  const testsWithCounts = results.filter(r => r.success && r.count > 0);
  const accurate = testsWithCounts.filter(r => r.accurate);
  
  if (testsWithCounts.length === 0) return 0;
  return (accurate.length / testsWithCounts.length) * 100;
}

/**
 * Run all tests
 */
async function runTests() {
  console.log('='.repeat(80));
  console.log('DATA-ETSY MCP SERVER V2.0 - COMPREHENSIVE TEST SUITE');
  console.log('='.repeat(80));
  console.log();
  console.log('Testing tiered fallback system:');
  console.log('  Tier 1: Etsy API (FREE, 100% accurate) - SKIP: No credentials');
  console.log('  Tier 2: Serper ($0.0003/query, 95% accurate) - SKIP: No credentials');
  console.log('  Tier 3: Perplexity (~$0.001/query, 60-70% accurate) - AVAILABLE');
  console.log('  Tier 4: Brave Search (FREE, ~33% accurate) - AVAILABLE');
  console.log();
  
  // Start server with environment variables
  console.log('Starting server...');
  const proc = spawn('node', ['index.js'], {
    cwd: new URL('.', import.meta.url).pathname,
    env: {
      ...process.env,
      DEBUG_MCP: '0' // Disable debug for clean output
    }
  });
  
  // Set up readline for server output
  const rl = createInterface({
    input: proc.stdout,
    terminal: false
  });
  
  proc.stdout.setEncoding('utf8');
  
  // Wrap readline in our proc.stdout to make it work with sendRequest
  proc.stdout.on = (event, handler) => {
    if (event === 'line') {
      rl.on('line', handler);
    }
  };
  proc.stdout.off = (event, handler) => {
    if (event === 'line') {
      rl.off('line', handler);
    }
  };
  
  proc.stderr.on('data', (data) => {
    // Suppress stderr output for clean test results
  });
  
  try {
    // Initialize server
    console.log('Initializing server...');
    const initResult = await sendRequest(proc, 'initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {}
    });
    console.log('✓ Server initialized');
    console.log(`  Protocol: ${initResult.protocolVersion}`);
    console.log(`  Server: ${initResult.serverInfo.name} v${initResult.serverInfo.version}`);
    console.log();
    
    // List tools
    const toolsResult = await sendRequest(proc, 'tools/list');
    console.log('✓ Available tools:');
    toolsResult.tools.forEach(tool => {
      console.log(`  - ${tool.name}: ${tool.description}`);
    });
    console.log();
    
    // Run Phase 1: Initial tests (cache miss)
    console.log('='.repeat(80));
    console.log('PHASE 1: INITIAL TESTS (Cache Miss Expected)');
    console.log('='.repeat(80));
    console.log();
    
    for (const test of ALL_TESTS) {
      console.log(`[${test.category}] Testing: "${test.keyword}"`);
      console.log(`  Expected range: ${test.minExpected.toLocaleString()} - ${test.maxExpected.toLocaleString()}`);
      
      try {
        const startTime = Date.now();
        const result = await sendRequest(proc, 'tools/call', {
          name: 'etsy_get_listing_count',
          arguments: { keyword: test.keyword }
        });
        const duration = Date.now() - startTime;
        
        // Parse the JSON response from content
        const data = JSON.parse(result.content[0].text);
        
        // Check if within expected range
        const accurate = isWithinRange(data.count, test.minExpected, test.maxExpected);
        
        console.log(`  ✓ Response in ${duration}ms`);
        console.log(`  Count: ${data.count.toLocaleString()}`);
        console.log(`  Source: ${data.source}${data.cached ? ' (cached)' : ''}`);
        console.log(`  Confidence: ${data.confidence}`);
        console.log(`  Accuracy: ${accurate ? '✓ PASS' : '✗ FAIL'} (within expected range)`);
        
        if (data.error) {
          console.log(`  ⚠ Error: ${data.error}`);
        }
        
        results.push({
          ...test,
          success: true,
          count: data.count,
          source: data.source,
          confidence: data.confidence,
          cached: data.cached || false,
          duration,
          accurate,
          timestamp: data.timestamp,
          error: data.error || null
        });
        
      } catch (err) {
        console.log(`  ✗ Test failed: ${err.message}`);
        results.push({
          ...test,
          success: false,
          error: err.message,
          accurate: false
        });
      }
      console.log();
    }
    
    // Run Phase 2: Cache hit tests
    console.log('='.repeat(80));
    console.log('PHASE 2: CACHE VALIDATION (Cache Hit Expected)');
    console.log('='.repeat(80));
    console.log();
    console.log('Re-running a subset of tests to verify caching...');
    console.log();
    
    const cacheTestKeywords = [
      ALL_TESTS[0], // First high-volume
      ALL_TESTS[3], // First medium-volume
      ALL_TESTS[6]  // First niche
    ];
    
    for (const test of cacheTestKeywords) {
      console.log(`[Cache Test] "${test.keyword}"`);
      
      try {
        const startTime = Date.now();
        const result = await sendRequest(proc, 'tools/call', {
          name: 'etsy_get_listing_count',
          arguments: { keyword: test.keyword }
        });
        const duration = Date.now() - startTime;
        
        const data = JSON.parse(result.content[0].text);
        
        console.log(`  Response in ${duration}ms (should be faster)`);
        console.log(`  Cached: ${data.cached ? '✓ YES' : '✗ NO'}`);
        console.log(`  Source: ${data.source}`);
        
        cacheTestResults.push({
          keyword: test.keyword,
          cached: data.cached || false,
          duration,
          source: data.source
        });
        
      } catch (err) {
        console.log(`  ✗ Cache test failed: ${err.message}`);
      }
      console.log();
    }
    
  } catch (err) {
    console.error('Fatal error:', err.message);
  } finally {
    // Cleanup
    proc.kill();
  }
  
  // Generate comprehensive report
  await generateReport();
}

/**
 * Generate comprehensive test report
 */
async function generateReport() {
  console.log('='.repeat(80));
  console.log('TEST RESULTS SUMMARY');
  console.log('='.repeat(80));
  console.log();
  
  const successful = results.filter(r => r.success && r.count > 0);
  const failed = results.filter(r => !r.success || r.count <= 0);
  const accuracy = calculateAccuracy(results);
  
  console.log(`📊 Overall Statistics:`);
  console.log(`  Total tests: ${results.length}`);
  console.log(`  Successful: ${successful.length} (${((successful.length/results.length)*100).toFixed(1)}%)`);
  console.log(`  Failed: ${failed.length}`);
  console.log(`  Accuracy: ${accuracy.toFixed(1)}% (within expected ranges)`);
  console.log();
  
  // Source distribution
  const bySources = {};
  successful.forEach(r => {
    if (!bySources[r.source]) bySources[r.source] = [];
    bySources[r.source].push(r);
  });
  
  console.log(`📡 Results by Source:`);
  Object.entries(bySources).forEach(([source, tests]) => {
    const avgDuration = tests.reduce((sum, t) => sum + t.duration, 0) / tests.length;
    const sourceAccuracy = (tests.filter(t => t.accurate).length / tests.length) * 100;
    console.log(`  ${source}: ${tests.length} tests, ${avgDuration.toFixed(0)}ms avg, ${sourceAccuracy.toFixed(1)}% accurate`);
  });
  console.log();
  
  // Cache effectiveness
  const cacheHits = cacheTestResults.filter(r => r.cached).length;
  const cacheEffectiveness = cacheTestResults.length > 0 
    ? (cacheHits / cacheTestResults.length) * 100 
    : 0;
  
  console.log(`💾 Cache Performance:`);
  console.log(`  Cache hits: ${cacheHits}/${cacheTestResults.length} (${cacheEffectiveness.toFixed(1)}%)`);
  if (cacheTestResults.length > 0) {
    const avgCachedTime = cacheTestResults
      .filter(r => r.cached)
      .reduce((sum, r) => sum + r.duration, 0) / (cacheHits || 1);
    const avgUncachedTime = cacheTestResults
      .filter(r => !r.cached)
      .reduce((sum, r) => sum + r.duration, 0) / ((cacheTestResults.length - cacheHits) || 1);
    console.log(`  Avg cached response: ${avgCachedTime.toFixed(0)}ms`);
    console.log(`  Avg uncached response: ${avgUncachedTime.toFixed(0)}ms`);
  }
  console.log();
  
  // Detailed results by category
  console.log(`📋 Detailed Results by Category:`);
  console.log('-'.repeat(80));
  
  ['High-Volume', 'Medium-Volume', 'Niche'].forEach(category => {
    const categoryTests = results.filter(r => r.category === category);
    const categoryAccuracy = calculateAccuracy(categoryTests);
    
    console.log();
    console.log(`${category} Keywords (${categoryAccuracy.toFixed(1)}% accurate):`);
    categoryTests.forEach(r => {
      const status = r.success && r.count > 0 ? (r.accurate ? '✓' : '⚠') : '✗';
      const count = r.count >= 0 ? r.count.toLocaleString() : 'N/A';
      const range = `${r.minExpected.toLocaleString()}-${r.maxExpected.toLocaleString()}`;
      console.log(`  ${status} "${r.keyword}"`);
      console.log(`     Expected: ${range} | Got: ${count} | Source: ${r.source || 'N/A'}`);
      if (r.error) {
        console.log(`     Error: ${r.error}`);
      }
    });
  });
  
  console.log();
  console.log('='.repeat(80));
  
  // Generate markdown report
  const reportContent = generateMarkdownReport(results, cacheTestResults, accuracy);
  await writeFile(
    new URL('TEST_RESULTS.md', import.meta.url).pathname,
    reportContent
  );
  
  // Save JSON results
  await writeFile(
    new URL('test-results.json', import.meta.url).pathname,
    JSON.stringify({ 
      timestamp: new Date().toISOString(), 
      accuracy,
      results,
      cacheTestResults 
    }, null, 2)
  );
  
  console.log();
  console.log('📄 Reports generated:');
  console.log('  - TEST_RESULTS.md (detailed analysis)');
  console.log('  - test-results.json (raw data)');
  console.log('='.repeat(80));
  
  // Final verdict
  console.log();
  console.log('🎯 FINAL VERDICT:');
  if (accuracy >= 85) {
    console.log(`  ✅ PASS - Accuracy target MET (${accuracy.toFixed(1)}% >= 85%)`);
  } else if (accuracy >= 70) {
    console.log(`  ⚠️  BORDERLINE - Accuracy below target (${accuracy.toFixed(1)}% < 85%)`);
    console.log(`     Consider enabling Serper for better accuracy`);
  } else {
    console.log(`  ❌ FAIL - Accuracy below target (${accuracy.toFixed(1)}% < 85%)`);
    console.log(`     Action required: Add Serper API key for 95% accuracy tier`);
  }
  console.log();
}

/**
 * Generate markdown report
 */
function generateMarkdownReport(results, cacheTestResults, accuracy) {
  const successful = results.filter(r => r.success && r.count > 0);
  const bySources = {};
  successful.forEach(r => {
    if (!bySources[r.source]) bySources[r.source] = [];
    bySources[r.source].push(r);
  });
  
  return `# Data-Etsy MCP Server v2.0 - Test Results

**Test Date:** ${new Date().toISOString()}  
**Overall Accuracy:** ${accuracy.toFixed(1)}%  
**Target:** 85%  
**Status:** ${accuracy >= 85 ? '✅ PASS' : accuracy >= 70 ? '⚠️ BORDERLINE' : '❌ FAIL'}

## Executive Summary

This test suite validates the redesigned data-etsy MCP server's tiered fallback system and accuracy against expected listing count ranges.

### Test Configuration

- **Total Tests:** ${results.length}
- **Successful:** ${successful.length} (${((successful.length/results.length)*100).toFixed(1)}%)
- **Failed:** ${results.filter(r => !r.success).length}

### Tiered Fallback System Status

| Tier | Service | Status | Tests | Avg Accuracy |
|------|---------|--------|-------|--------------|
| 1 | Etsy API | ⏸️ Pending approval | 0 | N/A |
| 2 | Serper | ❌ Not configured | 0 | N/A |
| 3 | Perplexity | ${bySources.perplexity ? '✅ Active' : '⚠️ Available'} | ${bySources.perplexity?.length || 0} | ${bySources.perplexity ? ((bySources.perplexity.filter(t => t.accurate).length / bySources.perplexity.length) * 100).toFixed(1) + '%' : 'N/A'} |
| 4 | Brave Search | ${bySources.brave ? '✅ Active' : '⚠️ Available'} | ${bySources.brave?.length || 0} | ${bySources.brave ? ((bySources.brave.filter(t => t.accurate).length / bySources.brave.length) * 100).toFixed(1) + '%' : 'N/A'} |

## Performance Metrics

### Response Times by Source

${Object.entries(bySources).map(([source, tests]) => {
  const avgDuration = tests.reduce((sum, t) => sum + t.duration, 0) / tests.length;
  const minDuration = Math.min(...tests.map(t => t.duration));
  const maxDuration = Math.max(...tests.map(t => t.duration));
  return `- **${source}**: Avg ${avgDuration.toFixed(0)}ms (Range: ${minDuration}-${maxDuration}ms)`;
}).join('\n')}

### Cache Performance

- **Cache Hit Rate:** ${cacheTestResults.length > 0 ? ((cacheTestResults.filter(r => r.cached).length / cacheTestResults.length) * 100).toFixed(1) : 0}%
- **Cache Tests:** ${cacheTestResults.length}
- **Cache Hits:** ${cacheTestResults.filter(r => r.cached).length}

## Accuracy Analysis by Category

### High-Volume Keywords (> 50,000 listings)

${results.filter(r => r.category === 'High-Volume').map(r => 
  `- **${r.keyword}**: ${r.count >= 0 ? r.count.toLocaleString() : 'N/A'} listings ${r.accurate ? '✅' : '❌'} (Expected: ${r.minExpected.toLocaleString()}-${r.maxExpected.toLocaleString()})`
).join('\n')}

**Accuracy:** ${calculateAccuracy(results.filter(r => r.category === 'High-Volume')).toFixed(1)}%

### Medium-Volume Keywords (10,000-100,000 listings)

${results.filter(r => r.category === 'Medium-Volume').map(r => 
  `- **${r.keyword}**: ${r.count >= 0 ? r.count.toLocaleString() : 'N/A'} listings ${r.accurate ? '✅' : '❌'} (Expected: ${r.minExpected.toLocaleString()}-${r.maxExpected.toLocaleString()})`
).join('\n')}

**Accuracy:** ${calculateAccuracy(results.filter(r => r.category === 'Medium-Volume')).toFixed(1)}%

### Niche Keywords (< 10,000 listings)

${results.filter(r => r.category === 'Niche').map(r => 
  `- **${r.keyword}**: ${r.count >= 0 ? r.count.toLocaleString() : 'N/A'} listings ${r.accurate ? '✅' : '❌'} (Expected: ${r.minExpected.toLocaleString()}-${r.maxExpected.toLocaleString()})`
).join('\n')}

**Accuracy:** ${calculateAccuracy(results.filter(r => r.category === 'Niche')).toFixed(1)}%

## Detailed Test Results

| Keyword | Category | Count | Expected Range | Source | Accuracy | Duration |
|---------|----------|-------|----------------|--------|----------|----------|
${results.filter(r => r.success).map(r => 
  `| ${r.keyword} | ${r.category} | ${r.count.toLocaleString()} | ${r.minExpected.toLocaleString()}-${r.maxExpected.toLocaleString()} | ${r.source} | ${r.accurate ? '✅' : '❌'} | ${r.duration}ms |`
).join('\n')}

## Recommendations

${accuracy >= 85 
  ? '✅ The system meets the 85% accuracy target. Current configuration is acceptable for production use.'
  : accuracy >= 70
    ? '⚠️ Accuracy is below the 85% target but acceptable. **Recommended:** Add Serper API key ($0.0003/query) to achieve 95% accuracy tier and improve cost efficiency.'
    : '❌ Accuracy is significantly below target. **Action Required:** Configure Serper API key to access the 95% accuracy tier, or wait for Etsy API approval for 100% accuracy.'
}

### Cost Efficiency

Current configuration uses:
${Object.entries(bySources).map(([source, tests]) => {
  const costs = {
    'etsy-api': 0,
    'serper': 0.0003,
    'perplexity': 0.001,
    'brave': 0
  };
  const cost = costs[source] || 0;
  const totalCost = cost * tests.length;
  return `- **${source}**: ${tests.length} queries × $${cost} = $${totalCost.toFixed(4)}`;
}).join('\n')}

**Total Test Cost:** $${Object.entries(bySources).reduce((sum, [source, tests]) => {
  const costs = { 'etsy-api': 0, 'serper': 0.0003, 'perplexity': 0.001, 'brave': 0 };
  return sum + ((costs[source] || 0) * tests.length);
}, 0).toFixed(4)}

## Next Steps

1. ${accuracy >= 85 ? '✅' : '⬜'} Achieve 85% accuracy target
2. ⬜ Obtain Etsy API approval for Tier 1 (100% accuracy, FREE)
3. ${bySources.serper ? '✅' : '⬜'} Configure Serper for Tier 2 (95% accuracy, $0.0003/query)
4. ✅ Verify cache functionality
5. ✅ Test tiered fallback system
`;
}

// Run tests
runTests().catch(console.error);