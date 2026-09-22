const https = require('https');
const { httpGet, httpPost, cookieJarFrom, cookieHeader } = require('./shared');

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

function extractFromBinresults(html) {
  const results = [];
  const binresultRe = /<div[^>]*class="[^"]*\bbinresult\b[^"]*"[\s\S]*?<\/div>\s*<\/div>/gi;
  let block;
  while ((block = binresultRe.exec(html)) !== null) {
    const chunk = block[0];
    const strongMatch = chunk.match(/<strong>([\s\S]*?)<\/strong>/i);
    const imgMatch = chunk.match(/<img[^>]*alt="([^"]*)"[^>]*>/i);
    if (!strongMatch || !imgMatch) continue;
    const dateText = strongMatch[1].trim();
    const binType = imgMatch[1].trim();
    if (!binType || binType === 'No bins') continue;
    const date = parseDerbyDate(dateText);
    if (!date) continue;
    results.push({ binType, date });
  }
  return results;
}

function extractFromStrongAndImg(html) {
  const results = [];
  const section = html.match(/<div[^>]*class="[^"]*\bapplicationwrapper\b[^"]*"[\s\S]*?<\/div>\s*<\/div>\s*<\/div>/i);
  const scope = section ? section[0] : html;

  const dateRe = /<strong>([\s\S]*?)<\/strong>/gi;
  const typeRe = /<img[^>]*alt="([^"]*)"[^>]*>/gi;
  const dates = [];
  const types = [];
  let m;
  while ((m = dateRe.exec(scope)) !== null) dates.push(m[1].trim());
  while ((m = typeRe.exec(scope)) !== null) types.push(m[1].trim());

  for (let i = 0; i < dates.length; i++) {
    const binType = types[i];
    if (!binType || binType === 'No bins' || binType === 'Household waste bin') continue;
    const date = parseDerbyDate(dates[i]);
    if (!date) continue;
    results.push({ binType, date });
  }
  return results;
}

module.exports = {
  id: 'derby',
  slug: 'derby',
  name: 'Derby City Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try {
      const pageRes = await httpGet('https://secure.derby.gov.uk/binday');
      if (pageRes.status !== 200) return [];
      const tokenMatch = pageRes.body.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/i);
      if (!tokenMatch) return [];
      const jar = cookieJarFrom(pageRes.headers);
      const cookies = cookieHeader(jar);
      const body = `Postcode=${encodeURIComponent(normalized)}&__RequestVerificationToken=${encodeURIComponent(tokenMatch[1])}`;
      const postRes = await httpPost('https://secure.derby.gov.uk/binday', body, { 'Cookie': cookies });
      let html = postRes.body;
      if (postRes.status === 302 && postRes.headers && postRes.headers.location) {
        const redirectUrl = postRes.headers.location.startsWith('http')
          ? postRes.headers.location
          : `https://secure.derby.gov.uk${postRes.headers.location}`;
        const redirRes = await httpGet(redirectUrl, { 'Cookie': cookies });
        html = redirRes.body;
      }
      const selectMatch = html.match(/<select[^>]*(?:id|name)="SelectedUprn"[^>]*>([\s\S]*?)<\/select>/i);
      if (!selectMatch) return [];
      const options = [];
      const optionRe = /<option\s+value="([^"]*)"[^>]*>([\s\S]*?)<\/option>/gi;
      let m;
      while ((m = optionRe.exec(selectMatch[1])) !== null) {
        const uprn = m[1].trim();
        const label = m[2].trim();
        if (!uprn || !label || label.includes('Select premises')) continue;
        options.push({ uprn, label });
      }
      return options;
    } catch (e) {
      console.error(`derby lookupAddresses error: ${e.message}`);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      let addressLabel = '';
      try {
        const addrs = await this.lookupAddresses(postcode || '');
        const match = addrs.find(a => a.uprn === String(uprn));
        if (match) addressLabel = match.label;
      } catch (_) {}
      const addrParam = addressLabel ? `?address=${encodeURIComponent(addressLabel)}` : '';
      const url = `https://secure.derby.gov.uk/binday/BinDays/${encodeURIComponent(uprn)}${addrParam}`;
      const result = await httpGet(url);
      if (result.status !== 200) {
        throw Object.assign(new Error(`Derby API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }

      const html = result.body;

      let parsed = extractFromBinresults(html);
      if (parsed.length === 0) {
        parsed = extractFromStrongAndImg(html);
      }
      if (parsed.length === 0) return [];

      const byStream = {};

      for (const entry of parsed) {
        const stream = STREAM_MAP[entry.binType];
        if (!stream) continue;

        if (!byStream[stream]) byStream[stream] = { stream, dates: [] };
        const dateStr = formatDate(entry.date);
        if (byStream[stream].dates.some(d => formatDate(d) === dateStr)) continue;
        byStream[stream].dates.push(entry.date);
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
