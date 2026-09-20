const https = require('https');
const { lookupAddressesOsPlaces } = require('./shared');

const SERVICE_MAP = {
  'domestic-waste-collection-service': 'general',
  'recycling-collection-service': 'recycling',
  'garden-waste-collection-service': 'garden',
};

const LABELS = {
  general: 'General Waste',
  recycling: 'Recycling',
  garden: 'Garden Waste',
};

function formatDate(d) {
  if (!d || !(d instanceof Date) || isNaN(d.getTime())) return null;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function deriveFrequency(dates) {
  if (dates.length < 2) return 'weekly';
  const gaps = [];
  for (let i = 1; i < dates.length; i++) {
    gaps.push(Math.round((dates[i] - dates[i - 1]) / 86400000));
  }
  const counts = {};
  for (const g of gaps) counts[g] = (counts[g] || 0) + 1;
  const mode = parseInt(Object.keys(counts).reduce((a, b) => counts[a] >= counts[b] ? a : b));
  if (mode <= 10) return 'weekly';
  if (mode <= 18) return 'fortnightly';
  if (mode <= 25) return 'threeWeekly';
  if (mode <= 35) return 'fourWeekly';
  if (mode <= 50) return 'sixWeekly';
  if (mode <= 70) return 'eightWeekly';
  return 'twelveWeekly';
}

function httpGet(urlStr) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      method: 'GET',
      hostname: url.hostname,
      path: url.pathname + url.search,
      headers: { 'User-Agent': 'erewash-bin-proxy/1.0', Accept: 'application/json' },
      timeout: 30000,
    };
    const req = https.request(opts, (resp) => {
      let body = '';
      resp.on('data', c => body += c);
      resp.on('end', () => resolve({ status: resp.statusCode, body }));
    });
    req.on('error', reject);
    req.setTimeout(30000, () => { req.destroy(new Error('timeout')); });
    req.end();
  });
}

module.exports = {
  id: 'erewash',
  slug: 'erewash',
  name: 'Erewash Borough Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try {
      return await lookupAddressesOsPlaces(normalized);
    } catch (e) {
      console.error(`erewash lookupAddresses error: ${e.message}`);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const url = `https://www.erewash.gov.uk/bbd-whitespace/one-year-collection-dates?uprn=${encodeURIComponent(uprn)}&_wrapper_format=drupal_ajax`;
      const result = await httpGet(url);
      if (result.status !== 200) {
        throw Object.assign(new Error(`Erewash API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }

      let data;
      try {
        data = JSON.parse(result.body);
      } catch (e) {
        throw Object.assign(new Error('Invalid JSON from Erewash API'), { code: 'PARSE_ERROR' });
      }

      if (!Array.isArray(data) || data.length === 0) return [];
      const settings = data[0] && data[0].settings && data[0].settings.collection_dates;
      if (!settings || typeof settings !== 'object') return [];

      const byStream = {};

      for (const key of Object.keys(settings)) {
        const collections = settings[key];
        if (!Array.isArray(collections)) continue;

        for (const item of collections) {
          const stream = SERVICE_MAP[item['service-identifier']];
          if (!stream) continue;
          if (!item.timestamp) continue;

          const date = new Date(item.timestamp * 1000);
          if (isNaN(date.getTime())) continue;

          if (!byStream[stream]) byStream[stream] = { stream, dates: [] };
          byStream[stream].dates.push(date);
        }
      }

      const results = [];
      for (const key of Object.keys(byStream)) {
        const b = byStream[key];
        if (b.dates.length === 0) continue;
        b.dates.sort((a, c) => a - c);
        const anchor = b.dates[0];
        const freq = deriveFrequency(b.dates);
        const nextCollections = b.dates.map(d => ({
          date: formatDate(d),
          stream: b.stream,
          label: LABELS[b.stream] || b.stream,
        }));
        results.push({
          stream: b.stream,
          dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
          frequency: freq,
          anchorDate: formatDate(anchor),
          nextCollections,
        });
      }

      return results;
    } catch (e) {
      console.error(`erewash getCollections error for uprn ${uprn}: ${e.message}`);
      return [];
    }
  },
};
