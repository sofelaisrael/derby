const { httpGet, httpPost, cookieJarFrom, cookieHeader, encodeForm } = require('./shared');

const BASE_URL = 'https://secure.derby.gov.uk';
const BIND_URL = `${BASE_URL}/binday`;
const MAX_REDIRECTS = 5;

const MONTHS = {
  january: 0, february: 1, march: 2, april: 3,
  may: 4, june: 5, july: 6, august: 7,
  september: 8, october: 9, november: 10, december: 11,
};

const STREAM_MAP = {
  'Black bin': 'general',
  'Black Bin': 'general',
  'black bin': 'general',
  'Blue bin': 'recycling',
  'Blue Bin': 'recycling',
  'blue bin': 'recycling',
  'Brown bin': 'garden',
  'Brown Bin': 'garden',
  'brown bin': 'garden',
  'Food bin': 'food',
  'Food Bin': 'food',
  'food bin': 'food',
  'General waste': 'general',
  'Recycling': 'recycling',
  'Garden waste': 'garden',
  'Food waste': 'food',
};

const STREAM_BY_ALT = Object.fromEntries(
  Object.entries(STREAM_MAP).map(([alt, stream]) => [alt.toLowerCase(), stream])
);

const IGNORED_ALTS = new Set(['no bins', 'household waste bin']);

const LABELS = {
  general: 'General Waste',
  recycling: 'Recycling',
  garden: 'Garden Waste',
  food: 'Food Waste',
};

function normalizePostcode(raw) {
  return (raw || '').trim().toUpperCase().replace(/\s+/g, '');
}

function absoluteUrl(location) {
  return location.startsWith('http') ? location : `${BASE_URL}${location}`;
}

function parseDerbyDate(text) {
  if (!text) return null;
  const match = text.trim().replace(/:$/, '').match(/,\s*(\d{1,2})\s+(\w+)\s+(\d{4})/);
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
  if (dates.length < 2) return null;
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

function extractCollections(html) {
  const results = [];
  const blocks = html.split(/<div[^>]*class="[^"]*\bbinresult\b[^"]*"[^>]*>/i);
  for (let i = 1; i < blocks.length; i++) {
    const block = blocks[i].split(/<hr\b/i)[0];
    const altMatch = block.match(/<img[^>]*\balt="([^"]*)"/i);
    const dateMatch = block.match(/<strong>([\s\S]*?)<\/strong>/i);
    if (!altMatch || !dateMatch) continue;
    const binType = altMatch[1].trim();
    if (!binType || IGNORED_ALTS.has(binType.toLowerCase())) continue;
    const date = parseDerbyDate(dateMatch[1]);
    if (!date) continue;
    results.push({ binType, date });
  }
  return results;
}

function parseAddressOptions(html) {
  const selectMatch = html.match(/<select[^>]*(?:id|name)="SelectedUprn"[^>]*>([\s\S]*?)<\/select>/i);
  if (!selectMatch) return [];
  const addresses = [];
  const optionRe = /<option\s+value="([^"]*)"[^>]*>([\s\S]*?)<\/option>/gi;
  let m;
  while ((m = optionRe.exec(selectMatch[1])) !== null) {
    const uprn = m[1].trim();
    const label = m[2].trim();
    if (!uprn || !label || label.includes('Select premises')) continue;
    addresses.push({ uprn, label });
  }
  return addresses;
}

async function openSession(postcode) {
  try {
    const pageRes = await httpGet(BIND_URL);
    if (pageRes.status !== 200) return null;
    const tokenMatch = pageRes.body.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/i);
    if (!tokenMatch) return null;

    const jar = cookieJarFrom(pageRes.headers);
    const postBody = encodeForm({ Postcode: postcode, __RequestVerificationToken: tokenMatch[1] });
    const postRes = await httpPost(BIND_URL, postBody, { Cookie: cookieHeader(jar) });
    Object.assign(jar, cookieJarFrom(postRes.headers));

    let html = postRes.body;
    let location = postRes.headers && postRes.headers.location;
    for (let hop = 0; location && hop < MAX_REDIRECTS; hop++) {
      const res = await httpGet(absoluteUrl(location), { Cookie: cookieHeader(jar) });
      Object.assign(jar, cookieJarFrom(res.headers));
      const next = res.headers && res.headers.location;
      if (res.status >= 300 && res.status < 400 && next) {
        location = next;
        continue;
      }
      html = res.body;
      location = null;
    }

    return { cookie: cookieHeader(jar), addresses: parseAddressOptions(html) };
  } catch (e) {
    console.error(`derby session error for ${postcode}: ${e.message}`);
    return null;
  }
}

module.exports = {
  id: 'derby',
  slug: 'derby',
  name: 'Derby City Council',

  async lookupAddresses(postcode) {
    const normalized = normalizePostcode(postcode);
    if (!normalized) return [];
    try {
      const session = await openSession(normalized);
      return session ? session.addresses : [];
    } catch (e) {
      console.error(`derby lookupAddresses error: ${e.message}`);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const normalized = normalizePostcode(postcode);
      let cookie = '';
      let addressLabel = '';

      if (normalized) {
        const session = await openSession(normalized);
        if (session) {
          cookie = session.cookie;
          const match = session.addresses.find(a => a.uprn === String(uprn));
          if (match) addressLabel = match.label;
        }
      }

      const addressParam = addressLabel ? `?address=${encodeURIComponent(addressLabel)}` : '';
      const headers = cookie ? { Cookie: cookie, Referer: BIND_URL } : undefined;
      const result = await httpGet(`${BIND_URL}/BinDays/${encodeURIComponent(uprn)}${addressParam}`, headers);
      if (result.status !== 200) {
        throw Object.assign(new Error(`Derby API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }

      const byStream = {};
      for (const entry of extractCollections(result.body)) {
        const stream = STREAM_BY_ALT[entry.binType.toLowerCase()];
        if (!stream) continue;
        const dateStr = formatDate(entry.date);
        if (!byStream[stream]) byStream[stream] = { dates: [], seen: new Set() };
        if (byStream[stream].seen.has(dateStr)) continue;
        byStream[stream].seen.add(dateStr);
        byStream[stream].dates.push(entry.date);
      }

      return Object.entries(byStream).map(([stream, bucket]) => {
        const dates = bucket.dates.slice().sort((a, b) => a - b);
        const anchor = dates[0];
        return {
          stream,
          dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
          frequency: deriveFrequency(dates),
          anchorDate: formatDate(anchor),
          nextCollections: dates.map(d => ({
            date: formatDate(d),
            stream,
            label: LABELS[stream] || stream,
          })),
        };
      });
    } catch (e) {
      console.error(`derby getCollections error for uprn ${uprn}: ${e.message}`);
      return [];
    }
  },
};
