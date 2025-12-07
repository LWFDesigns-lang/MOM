import { CircuitBreaker } from '../circuit-breaker.js';

/**
 * Perplexity AI Client
 * Tier 3 - AI-based estimation, ~60-70% accuracy
 */
export class PerplexityClient {
  constructor(options = {}) {
    this.apiKey = options.apiKey || process.env.PERPLEXITY_API_KEY;
    this.baseUrl = 'https://api.perplexity.ai/chat/completions';
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
    const overPattern = /(?:over|more than|approximately|around)\s*(\d{1,3}(?:,\d{3})*)/i;
    const overMatch = text.match(overPattern);
    if (overMatch) {
      return parseInt(overMatch[1].replace(/,/g, ''));
    }
    
    // Pattern for standalone numbers (as last resort)
    const numberPattern = /(\d{1,3}(?:,\d{3})+)/;
    const numberMatch = text.match(numberPattern);
    if (numberMatch) {
      return parseInt(numberMatch[1].replace(/,/g, ''));
    }
    
    return null;
  }

  /**
   * Get listing count using Perplexity AI
   * @param {string} keyword - Search keyword
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Result object
   */
  async getListingCount(keyword, options = {}) {
    if (!this.isConfigured()) {
      throw new Error('Perplexity API not configured (missing API key)');
    }

    if (!this.circuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is blocking Perplexity requests');
    }

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.requestTimeout);

      const response = await fetch(this.baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: 'sonar',
          messages: [
            {
              role: 'user',
              content: `How many listings exist on Etsy for the keyword '${keyword}'? Provide just the approximate number.`
            }
          ]
        }),
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`Perplexity API error: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      this.circuitBreaker.recordSuccess();

      // Extract the response text
      const responseText = data.choices?.[0]?.message?.content || '';
      
      // Try to extract a number from the response
      const count = this.extractCountFromText(responseText);
      
      if (count !== null) {
        return {
          success: true,
          keyword,
          count,
          source: 'perplexity',
          confidence: 'medium',
          responseText,
          timestamp: new Date().toISOString()
        };
      }
      
      throw new Error('Could not extract count from Perplexity response');

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