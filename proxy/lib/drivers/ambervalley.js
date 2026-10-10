const { httpGet, httpPost } = require('./shared');

// Key candidates per stream, most-canonical first. The AVBC feed spells its
// food field inconsistently across endpoints, so the food row accepts several
// spellings and finally sweeps for any food/next key rather than silently
// dropping the stream when none matches.
const STREAM_MAP = [
  { keys: ['refuseNextDate'], stream: 'general', label: 'General Waste' },
  { keys: ['recyclingNextDate'], stream: 'recycling', label: 'Recycling' },
  { keys: ['greenNextDate'], stream: 'garden', label: 'Garden Waste' },
  {
    keys: ['foodNextDate', 'nextFoodDate', 'NextFoodDate', 'FoodNextDate'],
    stream: 'food',
    label: 'Food Waste',
    sweep: true,
  },
  { keys: ['communalRefNextDate'], stream: 'general', label: 'General Waste' },
  { keys: ['communalRycNextDate'], stream: 'recycling', label: 'Recycling' },
];

function resolveDateKey(data, entry) {
  for (const key of entry.keys) {
    if (data[key]) return key;
  }
  if (!entry.sweep) return null;
  // Last resort: any remaining key that looks like a food next-date. Excludes
  // communal and frequency flags so only a real date field can match, and
  // requires an ISO-shaped value: `typeof === 'string'` alone let "12/03/2026"
  // through, and `new Date()` reads that as 3 December -- a plausible-looking
  // but wrong collection that survives both the isNaN and the year>=2000
  // checks downstream.
  return Object.keys(data).find(
    (k) => !entry.keys.includes(k)
      && /food/i.test(k)
      && /next/i.test(k)
      && !/communal|com/i.test(k)
      && !/weekly|frequency/i.test(k)
      && typeof data[k] === 'string'
      && /^\d{4}-\d{2}-\d{2}/.test(data[k]),
  ) || null;
}

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

function formatPostcode(raw) {
  const p = (raw || '').trim().toUpperCase().replace(/\s+/g, '');
  if (p.length < 5) return p;
  const inward = p.slice(-3);
  const outward = p.slice(0, -3);
  return `${outward} ${inward}`;
}

const LOOKUP_URL = 'https://info.ambervalley.gov.uk/WebServices/AVBCFeeds/GazetteerJSON.asmx/PropertyLookupFeed';
const COLLECTION_URL = 'https://info.ambervalley.gov.uk/WebServices/AVBCFeeds/WasteCollectionJSON.asmx/GetCollectionDetailsByUPRN';

// Extracted verbatim from getCollections so the fixtures can drive it with a
// fixed `now`. `oneYear` is passed in rather than read from the clock, exactly
// as before; nothing in the date math below has changed. `now` is accepted for
// call-shape uniformity with the other extracted builders and is unused -- this
// driver's date expansion never looked at the current date.
function buildCollectionsFromFeed(data, now, oneYear) {
  const results = [];

  for (const entry of STREAM_MAP) {
    const dateKey = resolveDateKey(data, entry);
    if (!dateKey) continue;
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
      stream: entry.stream,
      label: entry.label,
    })).filter(c => c.date);
    if (nextCollections.length === 0) continue;

    results.push({
      stream: entry.stream,
      dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
      frequency: freq,
      anchorDate: formatDate(anchor),
      nextCollections,
    });
  }

  return results;
}

module.exports = {
  id: 'ambervalley',
  slug: 'ambervalley',
  name: 'Amber Valley Borough Council',

  async lookupAddresses(postcode) {
    const formatted = formatPostcode(postcode);
    if (!formatted) return [];
    try {
      const formData = `srchText=${encodeURIComponent(formatted)}`;
      const result = await httpPost(LOOKUP_URL, formData, { 'Content-Type': 'application/x-www-form-urlencoded' });
      if (result.status !== 200) {
        throw Object.assign(new Error(`Amber Valley API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }
      let data;
      try { data = JSON.parse(result.body); } catch (e) { throw Object.assign(new Error('Invalid JSON from address lookup'), { code: 'PARSE_ERROR' }); }
      const list = Array.isArray(data) ? data : (data && Array.isArray(data.d) ? data.d : []);
      return list
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
      return buildCollectionsFromFeed(data, now, oneYear);
    } catch (e) {
      if (isTimeoutError(e)) throw new Error('Amber Valley API unreachable (may be UK-only)');
      throw e;
    }
  },

  // Pure exports for the fixture-driven regression suite in test/.
  _buildCollectionsFromFeed: buildCollectionsFromFeed,
  _resolveDateKey: resolveDateKey,
};
