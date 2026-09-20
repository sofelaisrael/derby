const https = require('https');
const { lookupAddressesOsPlaces } = require('./shared');

const MONTHS = {
  january: 0, february: 1, march: 2, april: 3,
  may: 4, june: 5, july: 6, august: 7,
  september: 8, october: 9, november: 10, december: 11,
};

const STREAM_MAP = {
  'Black bin': 'general',
  'Blue bin': 'recycling',
  'Brown bin': 'garden',
  'Food bin': 'food',
};

const LABELS = {
  general: 'General Waste',
  recycling: 'Recycling',
  garden: 'Garden Waste',
  food: 'Food Waste',
};

function parseDerbyDate(s) {
  if (!s) return null;
  const cleaned = s.replace(/:$/, '').trim();
  const match = cleaned.match(/,\s+(\d{1,2})\s+(\w+)\s+(\d{4})/);
  if (!match) return null;
  const day = parseInt(match[1], 10);
  const month = MONTHS[match[2].toLowerCase()];
  const year = parseInt(match[3], 10);
  if (isNaN(day) || month === undefined || isNaN(year)) return null;
  return new Date(year, month, day);
}

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
      headers: { 'User-Agent': 'derby-bin-proxy/1.0', Accept: 'text/html' },
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
  id: 'derby',
  slug: 'derby',
  name: 'Derby City Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try {
      return await lookupAddressesOsPlaces(normalized);
    } catch (e) {
      console.error(`derby lookupAddresses error: ${e.message}`);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const url = `https://secure.derby.gov.uk/binday/Bindays/${encodeURIComponent(uprn)}`;
      const result = await httpGet(url);
      if (result.status !== 200) {
        throw Object.assign(new Error(`Derby API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }

      const html = result.body;
      const container = html.match(/<div id="bindays-container">([\s\S]*?)(<\/div>\s*<\/div>\s*<\/div>|<hr|$)/i);
      const section = container ? container[0] : html;
      const dates = [];
      const types = [];
      const dateRe = /<strong>([\s\S]*?)<\/strong>/gi;
      const typeRe = /<img[^>]*alt="([^"]*)"[^>]*>/gi;
      let m;
      while ((m = dateRe.exec(section)) !== null) dates.push(m[1]);
      while ((m = typeRe.exec(section)) !== null) types.push(m[1]);
      if (dates.length === 0) return [];

      const byStream = {};

      for (let i = 0; i < dates.length; i++) {
        const binLabel = types[i];
        if (!binLabel) continue;
        const stream = STREAM_MAP[binLabel];
        if (!stream) continue;

        const date = parseDerbyDate(dates[i]);
        if (!date) continue;

        if (!byStream[stream]) byStream[stream] = { stream, dates: [] };
        const dateStr = formatDate(date);
        if (byStream[stream].dates.some(d => formatDate(d) === dateStr)) continue;
        byStream[stream].dates.push(date);
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
      console.error(`derby getCollections error for uprn ${uprn}: ${e.message}`);
      return [];
    }
  },
};
