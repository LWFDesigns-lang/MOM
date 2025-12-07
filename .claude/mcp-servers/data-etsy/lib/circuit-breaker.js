/**
 * Circuit Breaker Pattern Implementation
 * Prevents cascading failures by temporarily disabling failing services
 */
export class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 3;
    this.resetTimeout = options.resetTimeout || 5 * 60 * 1000; // 5 minutes default
    this.failures = 0;
    this.lastFailure = null;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
  }

  /**
   * Check if circuit breaker allows requests
   * @returns {boolean} True if requests are allowed
   */
  isOpen() {
    if (this.state === 'CLOSED') return true;
    
    if (this.state === 'OPEN') {
      // Check if reset timeout has passed
      if (Date.now() - this.lastFailure >= this.resetTimeout) {
        this.state = 'HALF_OPEN';
        return true; // Allow one test request
      }
      return false;
    }
    
    return true; // HALF_OPEN allows requests
  }

  /**
   * Record a successful request
   */
  recordSuccess() {
    this.failures = 0;
    this.state = 'CLOSED';
  }

  /**
   * Record a failed request
   */
  recordFailure() {
    this.failures++;
    this.lastFailure = Date.now();
    
    if (this.failures >= this.failureThreshold) {
      this.state = 'OPEN';
    }
  }

  /**
   * Get current state information
   * @returns {Object} State details
   */
  getState() {
    return {
      state: this.state,
      failures: this.failures,
      lastFailure: this.lastFailure,
      resetTimeout: this.resetTimeout
    };
  }
}