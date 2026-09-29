const { httpGet } = require('./shared');

const DATA_URL = 'https://maps.southderbyshire.gov.uk/ishareLIVE.Web/getdata.aspx';
const REFERER = 'https://maps.southderbyshire.gov.uk/ishareLIVE.Web/atmyresponsivecouncil.aspx';
const MAP_SOURCE = 'mapsources/MyHouse';
const COLLECTION_GROUP = 'Recycling Bins and Waste|Next Bin Collections';
const ADDRESS_PAGE_SIZE = 100;
const UPRN_RE = /^\d+$/;

const STREAM_MAP = { black: 'general', green: 'recycling', brown: 'garden', podback: 'food' };
const STREAM_PATTERNS = { black: /black/i, green: /green/i, brown: /brown/i, podback: /podback|food/i };
const STREAM_ORDER = ['general', 'recycling', 'garden', 'food'];
const LABELS = { general: 'Black bin', recycling: 'Green bin', garden: 'Brown bin', food: 'Food bin' };

const DATE_TEXT_RE = /(\d{1,2}\s+[A-Za-z]+\s+\d{4})/g;

const MONTHS = {
  january: 0, february: 1, march: 2, april: 3, may: 4, june: 5,
  july: 6, august: 7, september: 8, october: 9, november: 10, december: 11,
};

function extractDate(text) {
  const m = text.match(/(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})/);
  if (!m) return null;
  const month = MONTHS[m[2].toLowerCase()];
  if (month === undefined) return null;
  const date = new Date(parseInt(m[3], 10), month, parseInt(m[1], 10));
  return isNaN(date.getTime()) ? null : date;
}

function formatDate(d) {
  if (!(d instanceof Date) || isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function deriveFrequency(dates) {
  if (dates.length < 2) return null;
  const counts = {};
  for (let i = 1; i < dates.length; i++) {
    const gap = Math.round((dates[i] - dates[i - 1]) / 86400000);
    if (gap <= 0) continue;
    counts[gap] = (counts[gap] || 0) + 1;
  }
  const gaps = Object.keys(counts);
  if (gaps.length === 0) return null;
  const mode = Math.round(Number(gaps.reduce((a, b) => (counts[a] >= counts[b] ? a : b))));
  if (mode <= 10) return 'weekly';
  if (mode <= 18) return 'fortnightly';
  if (mode <= 25) return 'threeWeekly';
  if (mode <= 35) return 'fourWeekly';
  if (mode <= 50) return 'sixWeekly';
  if (mode <= 70) return 'eightWeekly';
  return 'twelveWeekly';
}

function htmlToText(html) {
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&#?\w+;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function streamsFromDescription(description) {
  const streams = [];
  for (const [key, pattern] of Object.entries(STREAM_PATTERNS)) {
    const stream = STREAM_MAP[key];
    if (pattern.test(description) && !streams.includes(stream)) streams.push(stream);
  }
  return streams;
}

function parseEntries(html) {
  const text = htmlToText(html);
  const matches = [...text.matchAll(DATE_TEXT_RE)];
  const entries = [];
  for (let i = 0; i < matches.length; i++) {
    const date = extractDate(matches[i][1]);
    if (!date) continue;
    const tailStart = i + 1 < matches.length ? matches[i + 1].index : text.length;
    const description = text.slice(matches[i].index + matches[i][0].length, tailStart).trim();
    const streams = streamsFromDescription(description);
    if (streams.length === 0) continue;
    entries.push({ date, streams });
  }
  return entries;
}

function parseAddresses(data) {
  if (!data || !Array.isArray(data.data)) return [];
  const columns = Array.isArray(data.columns) ? data.columns : [];
  const uprnIndex = columns.indexOf('UniqueId');
  const labelIndex = columns.indexOf('Name');
  const addresses = [];
  const seen = new Set();
  for (const row of data.data) {
    if (!Array.isArray(row)) continue;
    const uprn = String(row[uprnIndex >= 0 ? uprnIndex : 0] == null ? '' : row[uprnIndex >= 0 ? uprnIndex : 0]).trim();
    const label = String(row[labelIndex >= 0 ? labelIndex : 7] == null ? '' : row[labelIndex >= 0 ? labelIndex : 7]).trim();
    if (!uprn || !label || seen.has(uprn)) continue;
    seen.add(uprn);
    addresses.push({ uprn, label });
  }
  return addresses;
}

function buildCollections(entries) {
  const buckets = {};
  for (const entry of entries) {
    for (const stream of entry.streams) {
      if (!buckets[stream]) buckets[stream] = new Set();
      buckets[stream].add(entry.date);
    }
  }

  const today = startOfToday();
  const results = [];
  for (const stream of STREAM_ORDER) {
    const set = buckets[stream];
    if (!set) continue;
    const listed = [...set].sort((a, b) => a - b);
    const upcoming = listed.filter(d => d >= today);
    if (upcoming.length === 0) continue;
    const anchor = upcoming[0];
    results.push({
      stream,
      dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
      frequency: deriveFrequency(listed),
      anchorDate: formatDate(anchor),
      nextCollections: upcoming.map(d => ({
        date: formatDate(d),
        stream,
        label: LABELS[stream] || stream,
      })),
    });
  }
  return results;
}

module.exports = {
  id: 'southderbyshire',
  slug: 'southderbyshire',
  name: 'South Derbyshire District Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];

    const query = [
      'type=json',
      'service=LocationSearch',
      'RequestType=LocationSearch',
      `location=${encodeURIComponent(normalized)}`,
      `pagesize=${ADDRESS_PAGE_SIZE}`,
      'startnum=1',
      'gettotals=true',
      `mapsource=${encodeURIComponent(MAP_SOURCE)}`,
    ].join('&');

    const res = await httpGet(`${DATA_URL}?${query}`, { Referer: REFERER, Accept: 'application/json' });
    if (res.status !== 200) {
      throw Object.assign(new Error(`South Derbyshire address search returned ${res.status}`), { code: 'UPSTREAM_ERROR' });
    }

    const body = res.body.trim();
    if (!body) {
      console.error('[southderbyshire] lookupAddresses: no addresses for postcode %s', normalized);
      return [];
    }

    let data;
    try {
      data = JSON.parse(body);
    } catch (e) {
      throw Object.assign(new Error('South Derbyshire address search returned a non-JSON response'), { code: 'PARSE_ERROR' });
    }

    const addresses = parseAddresses(data);
    if (addresses.length === 0) console.error('[southderbyshire] lookupAddresses: no addresses for postcode %s', normalized);
    return addresses;
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];

    const target = String(uprn).trim();
    if (!UPRN_RE.test(target)) {
      console.error('[southderbyshire] getCollections: refusing non-numeric uprn %j', uprn);
      return [];
    }

    const query = [
      'type=json',
      'RequestType=LocalInfo',
      `ms=${encodeURIComponent(MAP_SOURCE)}`,
      'format=JSON',
      `group=${encodeURIComponent(COLLECTION_GROUP)}`,
      `uid=${encodeURIComponent(target)}`,
    ].join('&');

    const res = await httpGet(`${DATA_URL}?${query}`, { Referer: REFERER, Accept: 'application/json' });
    if (res.status !== 200) {
      throw Object.assign(new Error(`South Derbyshire collection lookup returned ${res.status} for uprn ${target}`), { code: 'UPSTREAM_ERROR' });
    }

    const body = res.body.trim();
    if (!body || body.startsWith('ERROR')) {
      console.error('[southderbyshire] getCollections: no collection data for uprn %s (%j)', target, body);
      return [];
    }

    let data;
    try {
      data = JSON.parse(body);
    } catch (e) {
      throw Object.assign(new Error(`South Derbyshire collection lookup returned a non-JSON response for uprn ${target}`), { code: 'PARSE_ERROR' });
    }

    const layer = data && data.Results && data.Results.Next_Bin_Collections;
    const html = layer && layer._;
    if (typeof html !== 'string' || !html) {
      console.error('[southderbyshire] getCollections: no Next_Bin_Collections layer for uprn %s', target);
      return [];
    }

    const entries = parseEntries(html);
    const collections = buildCollections(entries);
    if (collections.length === 0) {
      console.error('[southderbyshire] getCollections: %d parsed entries produced no upcoming collections for uprn %s', entries.length, target);
    }
    return collections;
  },
};
