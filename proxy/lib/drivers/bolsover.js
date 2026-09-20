const https = require('https');
const { lookupAddressesOsPlaces } = require('./shared');

const CALENDARS = ['a', 'b'];
const BASE = 'https://www.bolsover.gov.uk/waste-bins-recycling/bin-calendar-';
const MONTHS = { January: 1, February: 2, March: 3, April: 4, May: 5, June: 6, July: 7, August: 8, September: 9, October: 10, November: 11, December: 12 };

function httpGet(urlStr) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      method: 'GET', hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', Accept: 'text/html' },
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

function parseCalendarPage(html) {
  const results = [];
  const tableRe = /<table[^>]*>([\s\S]*?)<\/table>/gi;
  let tableMatch;
  while ((tableMatch = tableRe.exec(html)) !== null) {
    const tableHtml = tableMatch[1];
    let headingMatch = tableHtml.match(/<caption[^>]*>([\s\S]*?)<\/caption>/i);
    if (!headingMatch) {
      const prev = html.substring(0, html.indexOf(tableMatch[0]));
      const allH2 = [];
      const h2Re = /<h2[^>]*>([\s\S]*?)<\/h2>/gi;
      let hm;
      while ((hm = h2Re.exec(prev)) !== null) allH2.push(hm);
      if (allH2.length > 0) headingMatch = allH2[allH2.length - 1];
    }
    let month = 0, year = 0;
    if (headingMatch) {
      const text = headingMatch[1].replace(/<[^>]+>/g, '').trim();
      const m = text.match(/(\w+)\s+(\d{4})/);
      if (m && MONTHS[m[1]]) { month = MONTHS[m[1]]; year = parseInt(m[2]); }
    }
    if (!month || !year) continue;

    const rows = tableHtml.match(/<tr[^>]*>([\s\S]*?)<\/tr>/gi) || [];
    for (let ri = 1; ri < rows.length; ri++) {
      const cells = rows[ri].match(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi) || [];
      const cellTexts = cells.map(c => c.replace(/<[^>]+>/g, '').replace(/\(.*?\)/g, '').trim());
      if (cellTexts.length < 2) continue;
      const binLabel = cellTexts[0];
      if (!binLabel || binLabel.toLowerCase().includes('no collection')) continue;
      for (let ci = 1; ci < cellTexts.length; ci++) {
        const dayStr = cellTexts[ci];
        if (!dayStr || !dayStr.match(/^\d{1,2}$/)) continue;
        const day = parseInt(dayStr);
        try {
          const date = new Date(year, month - 1, day);
          if (!isNaN(date.getTime())) {
            const binTypes = binLabel.split('/').map(s => s.trim());
            for (const bt of binTypes) results.push({ date, binType: bt });
          }
        } catch (e) {}
      }
    }
  }
  return results;
}

function mapBinType(type) {
  const t = (type || '').toLowerCase();
  if (t.includes('black')) return 'general';
  if (t.includes('burgundy')) return 'recycling';
  if (t.includes('green')) return 'garden';
  return null;
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

module.exports = {
  id: 'bolsover',
  slug: 'bolsover',
  name: 'Bolsover District Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try { return await lookupAddressesOsPlaces(normalized); } catch (e) { return []; }
  },

  async getCollections(uprn, postcode) {
    try {
      const allEntries = [];
      for (const cal of CALENDARS) {
        const r = await httpGet(`${BASE}${cal}`);
        if (r.status !== 200) continue;
        const entries = parseCalendarPage(r.body);
        allEntries.push(...entries);
      }

      const byStream = {};
      const seen = new Set();
      for (const entry of allEntries) {
        const stream = mapBinType(entry.binType);
        if (!stream) continue;
        const key = `${stream}:${formatDate(entry.date)}`;
        if (seen.has(key)) continue;
        seen.add(key);
        if (!byStream[stream]) byStream[stream] = [];
        byStream[stream].push(entry.date);
      }

      const now = new Date();
      const results = [];
      for (const [stream, dates] of Object.entries(byStream)) {
        dates.sort((a, b) => a - b);
        const valid = dates.filter(d => d >= now);
        if (valid.length === 0) continue;
        const anchor = valid[0];
        const freq = deriveFrequency(valid);
        const label = { general: 'General Waste', recycling: 'Recycling', garden: 'Garden Waste' }[stream] || stream;
        const nextCollections = valid.map(d => ({ date: formatDate(d), stream, label }));
        results.push({
          stream,
          dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
          frequency: freq,
          anchorDate: formatDate(anchor),
          nextCollections,
        });
      }
      return results;
    } catch (e) { return []; }
  },
};
