const { httpGet } = require('./shared');

const STREAM_MAP = {
  refuseNextDate: { stream: 'general', label: 'General Waste' },
  recyclingNextDate: { stream: 'recycling', label: 'Recycling' },
  greenNextDate: { stream: 'garden', label: 'Garden Waste' },
  NextFoodDate: { stream: 'food', label: 'Food Waste' },
  communalRefNextDate: { stream: 'general', label: 'General Waste' },
  communalRycNextDate: { stream: 'recycling', label: 'Recycling' },
};

const SKIP_DATES = ['0001-01-01T00:00:00', '1900-01-01T00:00:00'];

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

function isTimeoutError(e) {
  return e && (e.message === 'timeout' || (e.code && (e.code === 'ETIMEDOUT' || e.code === 'ECONNRESET' || e.code === 'ENOTFOUND')));
}

const LOOKUP_URL = 'https://info.ambervalley.gov.uk/WebServices/AVBCFeeds/GazetteerJSON.asmx/PropertyLookupFeed';
const COLLECTION_URL = 'https://info.ambervalley.gov.uk/WebServices/AVBCFeeds/WasteCollectionJSON.asmx/GetCollectionDetailsByUPRN';

module.exports = {
  id: 'ambervalley',
  slug: 'ambervalley',
  name: 'Amber Valley Borough Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, ' ').replace(/\s{2,}/g, ' ');
    if (!normalized) return [];
    try {
      const url = `${LOOKUP_URL}?srchText=${encodeURIComponent(normalized)}`;
      const result = await httpGet(url, { Accept: 'application/json' });
      if (result.status !== 200) {
        throw Object.assign(new Error(`Amber Valley API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }
      let data;
      try { data = JSON.parse(result.body); } catch (e) { throw Object.assign(new Error('Invalid JSON from address lookup'), { code: 'PARSE_ERROR' }); }
      if (!Array.isArray(data)) return [];
      return data
        .filter(item => item.uprn)
        .map(item => ({ uprn: String(item.uprn), label: item.addressComma }));
    } catch (e) {
      if (isTimeoutError(e)) throw new Error('Amber Valley API unreachable (may be UK-only)');
      throw e;
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const url = `${COLLECTION_URL}?uprn=${encodeURIComponent(uprn)}`;
      const result = await httpGet(url, { Accept: 'application/json' });
      if (result.status !== 200) {
        throw Object.assign(new Error(`Amber Valley API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }
      let data;
      try { data = JSON.parse(result.body); } catch (e) { throw Object.assign(new Error('Invalid JSON from collection API'), { code: 'PARSE_ERROR' }); }

      const now = new Date();
      const oneYear = new Date(now.getFullYear() + 1, now.getMonth(), now.getDate());
      const results = [];

      for (const [dateKey, mapping] of Object.entries(STREAM_MAP)) {
        const rawDate = data[dateKey];
        if (!rawDate || SKIP_DATES.includes(rawDate)) continue;
        const date = new Date(rawDate);
        if (isNaN(date.getTime()) || date.getFullYear() < 2000) continue;

        const weeklyKey = dateKey === 'communalRefNextDate' || dateKey === 'communalRycNextDate'
          ? (dateKey === 'communalRefNextDate' ? 'communalRefWeekly' : 'communalRycWeekly')
          : 'weeklyCollection';
        const isWeekly = data[weeklyKey];
        const dayOffset = isWeekly ? 7 : 14;
        const dates = [];
        let d = new Date(date);
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
      if (isTimeoutError(e)) throw new Error('Amber Valley API unreachable (may be UK-only)');
      throw e;
    }
  },
};
