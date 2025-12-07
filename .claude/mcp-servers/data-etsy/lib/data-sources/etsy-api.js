import { CircuitBreaker } from '../circuit-breaker.js';

/**
 * Etsy Official API Client
 * Tier 1 - Most accurate, FREE but requires OAuth setup
 */
export class EtsyApiClient {
  constructor(options = {}) {
    this.apiKey = options.apiKey || process.env.ETSY_API_KEY;
    this.accessToken = options.accessToken || process.env.ETSY_ACCESS_TOKEN;
    this.baseUrl = 'https://openapi.etsy.com/v3/application';
    this.circuitBreaker = new CircuitBreaker({ 
      failureThreshold: 3,
      resetTimeout: 5 * 60 * 1000 // 5 minutes
    });
  }

  /**
   * Check if client is properly configured
   * @returns {boolean} True if configured
   */
  isConfigured() {
    return !!(this.apiKey && this.accessToken);
  }

  /**
   * Get listing count for keyword
   * @param {string} keyword - Search keyword
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Result object
   */
  async getListingCount(keyword, options = {}) {
    if (!this.isConfigured()) {
      throw new Error('Etsy API not configured (missing API key or access token)');
    }

    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is blocking Etsy API requests');
    }

    try {
      const params = new URLSearchParams({
        keywords: keyword,
        limit: 1, // Minimize data transfer - we only need the count
        state: 'active',
        ...options
      });

      const response = await fetch(
        `${this.baseUrl}/listings/active?${params.toString()}`,
        {
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
            'x-api-key': this.apiKey
          }
        }
      );

      if (!response.ok) {
        throw new Error(`Etsy API error: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      this.circuitBreaker.recordSuccess();

      return {
        success: true,
        keyword,
        count: data.count || 0,
        source: 'etsy-api',
        confidence: 'very_high',
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
      circuitBreaker: this.circuitBreaker.getState()
    };
  }
}