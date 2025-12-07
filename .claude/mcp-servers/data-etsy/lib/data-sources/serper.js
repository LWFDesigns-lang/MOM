import { CircuitBreaker } from '../circuit-breaker.js';

/**
 * Serper.dev Client
 * Tier 2 - Cheapest paid option at $0.0003/query, 95% accuracy
 */
export class SerperClient {
  constructor(options = {}) {
    this.apiKey = options.apiKey || process.env.SERPER_API_KEY;
    this.baseUrl = 'https://google.serper.dev';
    this.circuitBreaker = new CircuitBreaker({ 
      failureThreshold: 5,
      resetTimeout: 3 * 60 * 1000 // 3 minutes
    });
    this.costPerQuery = 0.0003;
  }

  /**
   * Check if client is properly configured
   * @returns {boolean} True if configured
   */
  isConfigured() {
    return !!this.apiKey;
  }

  /**
   * Get listing count for keyword using Google SERP data
   * @param {string} keyword - Search keyword
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Result object
   */
  async getListingCount(keyword, options = {}) {
    if (!this.isConfigured()) {
      throw new Error('Serper API not configured (missing API key)');
    }

    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is blocking Serper requests');
    }

    try {
      const searchQuery = `site:etsy.com ${keyword}`;
      
      const response = await fetch(`${this.baseUrl}/search`, {
        method: 'POST',
        headers: {
          'X-API-KEY': this.apiKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          q: searchQuery,
          gl: 'us',     // United States
          hl: 'en',     // English
          num: 10       // Results per page
        })
      });

      if (!response.ok) {
        throw new Error(`Serper API error: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      this.circuitBreaker.recordSuccess();

      // Extract total results count
      const totalResults = data.searchInformation?.totalResults;
      
      if (totalResults === undefined) {
        throw new Error('No totalResults in Serper response');
      }

      // Parse the count (may be string like "52,400")
      const count = typeof totalResults === 'string'
        ? parseInt(totalResults.replace(/,/g, ''))
        : totalResults;

      return {
        success: true,
        keyword,
        count,
        source: 'serper',
        confidence: 'high',
        searchQuery,
        cost: this.costPerQuery,
        timestamp: new Date().toISOString()
      };

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
      circuitBreaker: this.circuitBreaker.getState(),
      costPerQuery: this.costPerQuery
    };
  }
}