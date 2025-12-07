import { readFile, writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { dirname } from 'path';

/**
 * In-memory LRU Cache with File Persistence
 * Stores Etsy listing counts with TTL and automatic eviction
 */
export class ListingCountCache {
  constructor(options = {}) {
    this.maxSize = options.maxSize || 1000;
    this.defaultTtl = options.defaultTtl || 6 * 60 * 60 * 1000; // 6 hours
    this.cacheFile = options.cacheFile || '.cache/etsy-listing-counts.json';
    this.cache = new Map();
    this.syncInterval = null;
  }

  /**
   * Initialize cache by loading from file and starting periodic sync
   */
  async initialize() {
    await this.loadFromFile();
    // Periodic sync every 5 minutes
    this.syncInterval = setInterval(() => this.saveToFile(), 5 * 60 * 1000);
  }

  /**
   * Get cached entry for keyword
   * @param {string} keyword - Search keyword
   * @returns {Object|null} Cached entry or null
   */
  async get(keyword) {
    const normalizedKey = this.normalizeKey(keyword);
    const entry = this.cache.get(normalizedKey);
    
    if (!entry) return null;
    
    if (this.isExpired(entry)) {
      this.cache.delete(normalizedKey);
      return null;
    }

    // Update access time for LRU
    entry.lastAccess = Date.now();
    return entry;
  }

  /**
   * Set cache entry for keyword
   * @param {string} keyword - Search keyword
   * @param {Object} result - Query result
   * @param {Object} options - Options (ttl override)
   */
  async set(keyword, result, options = {}) {
    const normalizedKey = this.normalizeKey(keyword);
    const ttl = this.getTtlForSource(result.source, options.ttl);
    
    const entry = {
      keyword,
      count: result.count,
      source: result.source,
      confidence: result.confidence,
      createdAt: Date.now(),
      expiresAt: Date.now() + ttl,
      lastAccess: Date.now()
    };

    // Enforce max size with LRU eviction
    if (this.cache.size >= this.maxSize) {
      this.evictLRU();
    }

    this.cache.set(normalizedKey, entry);
  }

  /**
   * Get TTL based on data source reliability
   * @param {string} source - Data source name
   * @param {number} customTtl - Custom TTL override
   * @returns {number} TTL in milliseconds
   */
  getTtlForSource(source, customTtl) {
    if (customTtl) return customTtl;
    
    // Different TTLs based on data source reliability
    const ttlBySource = {
      'etsy-api': 6 * 60 * 60 * 1000,   // 6 hours (most reliable)
      'serper': 4 * 60 * 60 * 1000,     // 4 hours
      'perplexity': 1 * 60 * 60 * 1000, // 1 hour (estimates)
      'brave': 30 * 60 * 1000,          // 30 minutes (least reliable)
      'cache': this.defaultTtl
    };
    
    return ttlBySource[source] || this.defaultTtl;
  }

  /**
   * Normalize keyword for consistent cache keys
   * @param {string} keyword - Raw keyword
   * @returns {string} Normalized key
   */
  normalizeKey(keyword) {
    return keyword.toLowerCase().trim().replace(/\s+/g, ' ');
  }

  /**
   * Check if entry has expired
   * @param {Object} entry - Cache entry
   * @returns {boolean} True if expired
   */
  isExpired(entry) {
    return Date.now() > entry.expiresAt;
  }

  /**
   * Evict least recently used entry
   */
  evictLRU() {
    let oldestKey = null;
    let oldestAccess = Infinity;

    for (const [key, entry] of this.cache) {
      if (entry.lastAccess < oldestAccess) {
        oldestAccess = entry.lastAccess;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      this.cache.delete(oldestKey);
    }
  }

  /**
   * Load cache from file
   */
  async loadFromFile() {
    try {
      if (!existsSync(this.cacheFile)) {
        return;
      }

      const data = await readFile(this.cacheFile, 'utf8');
      const entries = JSON.parse(data);
      
      for (const entry of entries) {
        if (!this.isExpired(entry)) {
          this.cache.set(this.normalizeKey(entry.keyword), entry);
        }
      }
    } catch (error) {
      // File doesn't exist or is invalid, start fresh
      console.error('[Cache] Failed to load from file:', error.message);
    }
  }

  /**
   * Save cache to file
   */
  async saveToFile() {
    try {
      const entries = Array.from(this.cache.values())
        .filter(entry => !this.isExpired(entry));
      
      // Ensure directory exists
      const dir = dirname(this.cacheFile);
      if (!existsSync(dir)) {
        await mkdir(dir, { recursive: true });
      }

      await writeFile(this.cacheFile, JSON.stringify(entries, null, 2));
    } catch (error) {
      console.error('[Cache] Failed to save to file:', error.message);
    }
  }

  /**
   * Shutdown cache (save and clear interval)
   */
  async shutdown() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }
    await this.saveToFile();
  }

  /**
   * Get cache statistics
   * @returns {Object} Cache stats
   */
  getStats() {
    const now = Date.now();
    let validEntries = 0;
    let expiredEntries = 0;

    for (const entry of this.cache.values()) {
      if (this.isExpired(entry)) {
        expiredEntries++;
      } else {
        validEntries++;
      }
    }

    return {
      size: this.cache.size,
      maxSize: this.maxSize,
      validEntries,
      expiredEntries,
      hitRate: 0 // Can be tracked separately if needed
    };
  }
}