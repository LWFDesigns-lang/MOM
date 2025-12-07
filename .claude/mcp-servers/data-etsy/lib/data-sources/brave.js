import { CircuitBreaker } from '../circuit-breaker.js';

/**
 * Brave Search Client
 * Tier 4 - Last resort fallback, ~33% accuracy
 */
export class BraveClient {
  constructor(options = {}) {
    this.apiKey = options.apiKey || process.env.BRAVE_API_KEY;
    this.baseUrl = 'https://api.search.brave.com/res/v1/web/search';
    this.circuitBreaker = new CircuitBreaker({ 
      failureThreshold: 5,
      resetTimeout: 3 * 60 * 1000 // 3 minutes
    });
    this.requestTimeout = 10000; // 10 seconds
  }

  /**
   * Check if client is properly configured
   * @returns {boolean} True if configured
   */
  isConfigured() {
    return !!this.apiKey;
  }

  /**
   * Extract count from text using regex patterns
   * @param {string} text - Text to extract from
   * @returns {number|null} Extracted count or null
   */
  extractCountFromText(text) {
    // Pattern for comma-separated numbers followed by "results" or "listings"
    const resultsPattern = /(\d{1,3}(?:,\d{3})*)\s*(?:results?|listings?)/i;
    const resultsMatch = text.match(resultsPattern);
    if (resultsMatch) {
      return parseInt(resultsMatch[1].replace(/,/g, ''));
    }
    
    // Pattern for numbers in parentheses
    const parenthesesPattern = /\((\d{1,3}(?:,\d{3})*)\)/;
    const parenthesesMatch = text.match(parenthesesPattern);
    if (parenthesesMatch) {
      return parseInt(parenthesesMatch[1].replace(/,/g, ''));
    }
    
    // Pattern for "Over X" or "More than X"
    const overPattern = /(?:over|more than)\s*(\d{1,3}(?:,\d{3})*)/i;
    const overMatch = text.match(overPattern);
    if (overMatch) {
      return parseInt(overMatch[1].replace(/,/g, ''));
    }
    
    return null;
  }

  /**
   * Get listing count using Brave Search
   * @param {string} keyword - Search keyword
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Result object
   */
  async getListingCount(keyword, options = {}) {
    if (!this.isConfigured()) {
      throw new Error('Brave Search API not configured (missing API key)');
    }

    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is blocking Brave Search requests');
    }

    try {
      const query = `site:etsy.com "${keyword}" OR "${keyword}" etsy listings`;
      
      const url = new URL(this.baseUrl);
      url.searchParams.append('q', query);
      url.searchParams.append('count', '10');

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.requestTimeout);

      const response = await fetch(url.toString(), {
        method: 'GET',
        headers: {
          'X-Subscription-Token': this.apiKey,
          'Accept': 'application/json'
        },
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`Brave API error: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      this.circuitBreaker.recordSuccess();

      // Try to extract count from various fields in the response
      let count = null;
      
      // Check web results descriptions and titles
      if (data.web?.results) {
        const combinedText = data.web.results
          .map(r => `${r.title || ''} ${r.description || ''}`)
          .join(' ');
        count = this.extractCountFromText(combinedText);
      }
      
      // Check query string context
      if (!count && data.query?.original) {
        count = this.extractCountFromText(data.query.original);
      }
      
      // Check if there's a total results count in the response
      if (!count && data.web?.total) {
        count = parseInt(data.web.total);
      }
      
      if (count !== null) {
        return {
          success: true,
          keyword,
          count,
          source: 'brave',
          confidence: 'low',
          query,
          timestamp: new Date().toISOString()
        };
      }
      
      throw new Error('Could not extract count from Brave Search results');

    } catch (error) {
      this.circuitBreaker.recordFailure();
      throw error;
    }
  }

  /**
   * Get circuit breaker state
   * @returns {Object} State information
   */
  getState() {
    return {
      configured: this.isConfigured(),
      circuitBreaker: this.circuitBreaker.getState()
    };
  }
}