const { httpGet } = require('./shared');

const STREAM_MAP = {
  refuseNextDate: { stream: 'general', label: 'General Waste' },
  recyclingNextDate: { stream: 'recycling', label: 'Recycling' },
  greenNextDate: { stream: 'garden', label: 'Garden Waste' },
  NextFoodDate: { stream: 'food', label: 'Food Waste' },
  communalRefNextDate: { stream: 'general', label: 'General Waste' },
  communalRycNextDate: { stream: 'recycling', label: 'Recycling' },
};

const FREQ_KEY = {
  refuseNextDate: 'weeklyCollection',
  recyclingNextDate: 'weeklyCollection',
  greenNextDate: 'weeklyCollection',
  NextFoodDate: 'weeklyCollection',
  communalRefNextDate: 'communalRefWeekly',
  communalRycNextDate: 'communalRycWeekly',
};

const SKIP_DATES = ['0001-01-01T00:00:00', '0001-01-01T00:00:00+00:00'];

function formatDate(d) {
  if (!d || !(d instanceof Date) || isNaN(d.getTime())) return null;
  const y = d.getFullYear();
  if (y < 2000) return null;
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function deriveFrequency(dates) {
  if (dates.length < 2) return 'fortnightly';
  const gaps = [];
  for (let i = 1; i < dates.length; i++) gaps.push(Math.round((dates[i] - dates[i - 1]) / 86400000));
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

async function httpGetWithRetry(urlStr, extraHeaders, maxRetries) {
  const retries = maxRetries || 2;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const result = await httpGet(urlStr, extraHeaders);
      if (result.status !== 429 && result.status !== 503) return result;
      if (attempt === retries) return result;
    } catch (e) {
      if (attempt === retries) throw e;
    }
    await new Promise(r => setTimeout(r, 1000 + attempt * 1000));
  }
}

module.exports = {
  id: 'ambervalley',
  slug: 'ambervalley',
  name: 'Amber Valley Borough Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    return [];
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const url = `https://info.ambervalley.gov.uk/WebServices/AVBCFeeds/WasteCollectionJSON.asmx/GetCollectionDetailsByUPRN?uprn=${encodeURIComponent(uprn)}`;
      const result = await httpGetWithRetry(url, { 'Accept': 'application/json' }, 2);
      if (result.status !== 200) throw Object.assign(new Error(`Amber Valley API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });

      let data;
      try { data = JSON.parse(result.body); } catch (e) { throw Object.assign(new Error('Invalid JSON'), { code: 'PARSE_ERROR' }); }

      if (SKIP_DATES.includes(data.refuseNextDate) && SKIP_DATES.includes(data.recyclingNextDate)) return [];

      const results = [];
      const now = new Date();

      for (const [dateKey, mapping] of Object.entries(STREAM_MAP)) {
        const rawDate = data[dateKey];
        if (!rawDate || SKIP_DATES.includes(rawDate)) continue;
        const date = new Date(rawDate);
        if (isNaN(date.getTime()) || date.getFullYear() < 2000) continue;

        const isWeekly = data[FREQ_KEY[dateKey]];
        const dayOffset = isWeekly ? 7 : 14;
        const dates = [];
        let d = new Date(date);
        const oneYear = new Date(now.getFullYear() + 1, now.getMonth(), now.getDate());
        while (d <= oneYear) {
          dates.push(new Date(d));
          d = new Date(d.getTime() + dayOffset * 86400000);
        }

        if (dates.length === 0) continue;
        const anchor = dates[0];
        const freq = deriveFrequency(dates);
        const nextCollections = dates.map(dd => ({
          date: formatDate(dd),
          stream: mapping.stream,
          label: mapping.label,
        })).filter(c => c.date);
        if (nextCollections.length === 0) continue;
        results.push({
          stream: mapping.stream,
          dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
          frequency: freq,
          anchorDate: formatDate(anchor),
          nextCollections,
        });
      }

      return results;
    } catch (e) {
      console.error(`ambervalley getCollections error for uprn ${uprn}: ${e.message}`);
      return [];
    }
  },
};
