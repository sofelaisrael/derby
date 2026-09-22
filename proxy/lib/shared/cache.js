const cache = new Map();

function cacheGet(key) {
  const entry = cache.get(key);
  if (!entry) return undefined;
  if (Date.now() > entry.expiresAt) {
    cache.delete(key);
    return undefined;
  }
  return entry.value;
}

function cacheSet(key, value, ttlMs) {
  cache.set(key, { value, expiresAt: Date.now() + (ttlMs || 3600000) });
}

function cacheKey(...parts) {
  return parts.join(':');
}

module.exports = { cacheGet, cacheSet, cacheKey };
