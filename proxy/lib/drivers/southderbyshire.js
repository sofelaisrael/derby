const https = require('https');

const API_URL = 'https://maps.southderbyshire.gov.uk/iShareLIVE.Web/getdata.aspx?callback=test&RequestType=LocalInfo&ms=mapsources/MyHouse&format=JSONP&group=Recycling%20Bins%20and%20Waste|Next%20Bin%20Collections&uid=';

const STREAM_MAP = { black: 'general', green: 'recycling', brown: 'garden', podback: 'food' };
const LABELS = { general: 'Black bin', recycling: 'Green bin', garden: 'Brown bin', food: 'Podback' };

const IMG_STREAM_MAP = {
  blackweek: ['general'],
  greenweek: ['recycling', 'garden'],
  podback: ['food'],
};

const DESC_STREAM_MAP = [
  { pattern: /black.*food/i, streams: ['general', 'food'] },
  { pattern: /green.*brown.*food/i, streams: ['recycling', 'garden', 'food'] },
  { pattern: /green.*brown/i, streams: ['recycling', 'garden'] },
  { pattern: /black/i, streams: ['general'] },
  { pattern: /green/i, streams: ['recycling'] },
  { pattern: /brown/i, streams: ['garden'] },
  { pattern: /food/i, streams: ['food'] },
  { pattern: /podback/i, streams: ['food'] },
];

function httpGet(urlStr) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      method: 'GET', hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', Accept: '*/*' },
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

function extractDate(text) {
  const m = text.match(/(\d{1,2})\s+(\w+)\s+(\d{4})/);
  if (!m) return null;
  const months = { January: 0, February: 1, March: 2, April: 3, May: 4, June: 5, July: 6, August: 7, September: 8, October: 9, November: 10, December: 11 };
  const month = months[m[2]];
  if (month === undefined) return null;
  return new Date(parseInt(m[3]), month, parseInt(m[1]));
}

function formatDate(d) {
  if (!d || !(d instanceof Date) || isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
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

function parseEntries(html) {
  const entries = [];
  const blockRe = /<div[^>]*style="margin:\s*20px\s*0;"[^>]*>\s*<div[^>]*>([\s\S]*?)<\/div>\s*<\/div>/gi;
  let m;
  while ((m = blockRe.exec(html)) !== null) {
    const block = m[1];
    const dateSpan = block.match(/<span[^>]*style="[^"]*font-size:\s*22px[^"]*"[^>]*>([\s\S]*?)<\/span>/i);
    const descSpan = block.match(/<span[^>]*style="[^"]*text-align:\s*right;"[^>]*>([\s\S]*?)<\/span>/i);
    const imgTag = block.match(/<img[^>]*src="[^"]*?\/([^"\/]+)\.png"[^>]*>/i);

    const dateText = dateSpan ? dateSpan[1].trim() : null;
    const descText = descSpan ? descSpan[1].trim() : null;
    const imgName = imgTag ? imgTag[1].toLowerCase() : null;

    if (!dateText) continue;
    const date = extractDate(dateText);
    if (!date) continue;

    let streams = [];

    if (imgName && IMG_STREAM_MAP[imgName]) {
      streams = IMG_STREAM_MAP[imgName];
    } else if (descText) {
      for (const rule of DESC_STREAM_MAP) {
        if (rule.pattern.test(descText)) {
          streams = rule.streams;
          break;
        }
      }
    }

    if (streams.length === 0) continue;
    entries.push({ date, streams });
  }
  return entries;
}

module.exports = {
  id: 'southderbyshire',
  slug: 'southderbyshire',
  name: 'South Derbyshire District Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    const url = `https://maps.southderbyshire.gov.uk/iShareLIVE.Web/getdata.aspx?callback=cb&RequestType=LocationSearch&service=LocationSearch&pagesize=100&startnum=1&mapsource=mapsources/MyHouse&location=${encodeURIComponent(normalized)}`;
    const r = await httpGet(url);
    if (r.status !== 200) throw Object.assign(new Error(`Address search returned ${r.status}`), { code: 'UPSTREAM_ERROR' });
    let data;
    try { data = JSON.parse(r.body); } catch (e) { throw Object.assign(new Error('Invalid JSON from address search'), { code: 'PARSE_ERROR' }); }
    if (!data.data || !Array.isArray(data.data)) return [];
    return data.data.map(item => ({ uprn: item[0], label: item[7] }));
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const r = await httpGet(`${API_URL}${encodeURIComponent(uprn)}`);
      console.error('[southderbyshire] API status=%d', r.status);
      if (r.status !== 200) throw Object.assign(new Error(`API returned ${r.status}`), { code: 'UPSTREAM_ERROR' });

      let raw = r.body;
      if (raw.startsWith('test(') && raw.endsWith(');')) {
        raw = raw.slice(5, -2);
      }
      let data;
      try { data = JSON.parse(raw); } catch (e) { throw Object.assign(new Error('Invalid JSON'), { code: 'PARSE_ERROR' }); }

      const html = data.Results && data.Results.Next_Bin_Collections && data.Results.Next_Bin_Collections._;
      if (!html) return [];

      const entries = parseEntries(html);
      console.error('[southderbyshire] entries=%d', entries.length);
      if (entries.length === 0) return [];

      const byStream = {};
      const seen = new Set();
      for (const entry of entries) {
        for (const rawStream of entry.streams) {
          const stream = STREAM_MAP[rawStream] || rawStream;
          const dateStr = formatDate(entry.date);
          const key = `${stream}:${dateStr}`;
          if (seen.has(key)) continue;
          seen.add(key);
          if (!byStream[stream]) byStream[stream] = [];
          byStream[stream].push(entry.date);
        }
      }

      const results = [];
      for (const [stream, streamDates] of Object.entries(byStream)) {
        streamDates.sort((a, b) => a - b);
        const anchor = streamDates[0];
        const freq = deriveFrequency(streamDates);
        const nextCollections = streamDates.map(d => ({
          date: formatDate(d),
          stream,
          label: LABELS[stream] || stream,
        }));
        results.push({
          stream,
          dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
          frequency: freq,
          anchorDate: formatDate(anchor),
          nextCollections,
        });
      }
      return results;
    } catch (e) { console.error('[southderbyshire] getCollections error:', e.message); throw e; }
  },
};
