const { lookupAddressesOsPlaces, httpGet, httpPost, cookieJarFrom, cookieHeader, encodeForm } = require('./shared');

const BASE = 'https://bins.highpeak.gov.uk/PublicDashboard';

const TOKEN_RE = /name="__RequestVerificationToken"[^>]*value="([^"]+)"/;
const DATASOURCE_RE = /dataSource":\s*ejs\.data\.DataUtil\.parse\.isJson\(\s*(\[[\s\S]*?\])\s*\)/g;

function extractToken(html) {
  const m = html.match(TOKEN_RE);
  return m ? m[1] : '';
}

function extractJsonBlocks(html) {
  const blocks = [];
  let m;
  while ((m = DATASOURCE_RE.exec(html)) !== null) {
    try {
      const parsed = JSON.parse(m[1]);
      if (Array.isArray(parsed)) blocks.push(parsed);
    } catch (e) {}
  }
  return blocks;
}

function formatDate(d) {
  if (!d || !(d instanceof Date) || isNaN(d.getTime())) return null;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function mapHighPeakType(subject) {
  const s = (subject || '').toLowerCase();
  if (s.includes('rubbish') || s.includes('refuse') || s.includes('general') || s.includes('household')) return 'general';
  if (s.includes('recycl')) return 'recycling';
  if (s.includes('food') || s.includes('organic')) return 'food';
  if (s.includes('garden')) return 'garden';
  return null;
}

function streamLabel(stream) {
  const labels = { general: 'General Waste', recycling: 'Recycling', food: 'Food Waste', garden: 'Garden Waste' };
  return labels[stream] || stream;
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
  id: 'highpeak',
  slug: 'highpeak',
  name: 'High Peak Borough Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try {
      const jar = {};
      const r1 = await httpGet(BASE);
      Object.assign(jar, cookieJarFrom(r1.headers));
      const token = extractToken(r1.body);
      if (!token) return [];

      const body = encodeForm({ __RequestVerificationToken: token, SelectedPostcode: normalized });
      const r2 = await httpPost(`${BASE}?handler=SearchPostcode`, body, { Cookie: cookieHeader(jar) });
      Object.assign(jar, cookieJarFrom(r2.headers));

      const blocks = extractJsonBlocks(r2.body);
      const premisesBlock = blocks.find(b => b.length > 0 && b[0].UPRN);
      if (!premisesBlock) return [];

      const seen = new Set();
      const addrs = [];
      for (const item of premisesBlock) {
        const uprn = String(parseInt(item.UPRN));
        if (seen.has(uprn)) continue;
        seen.add(uprn);
        const label = item.Address || item.Premises || item.Property || uprn;
        addrs.push({ uprn, label });
      }
      if (addrs.length === 0) return await lookupAddressesOsPlaces(normalized);
      return addrs;
    } catch (e) { return []; }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '') || '';
      let jar = {};
      let token = '';

      const r1 = await httpGet(BASE);
      jar = cookieJarFrom(r1.headers);
      token = extractToken(r1.body);
      if (!token) return [];

      if (normalized) {
        const body = encodeForm({ __RequestVerificationToken: token, SelectedPostcode: normalized });
        const r2 = await httpPost(`${BASE}?handler=SearchPostcode`, body, { Cookie: cookieHeader(jar) });
        jar = Object.assign(jar, cookieJarFrom(r2.headers));
        token = extractToken(r2.body);
      }

      const selectBody = encodeForm({
        __RequestVerificationToken: token,
        SelectedPostcode: normalized,
        SelectedPremises: uprn,
      });
      const r3 = await httpPost(`${BASE}?handler=SelectPrem`, selectBody, { Cookie: cookieHeader(jar) });

      const blocks = extractJsonBlocks(r3.body);
      const scheduleBlock = blocks.find(b => b.length > 0 && b[0].Subject);
      if (!scheduleBlock) return [];

      const byStream = {};
      const seen = new Set();
      for (const item of scheduleBlock) {
        const subject = item.Subject;
        const dateStr = item.StartTime;
        if (!subject || !dateStr) continue;
        const date = new Date(dateStr);
        if (isNaN(date.getTime())) continue;
        const stream = mapHighPeakType(subject);
        if (!stream) continue;
        const key = `${stream}:${formatDate(date)}`;
        if (seen.has(key)) continue;
        seen.add(key);
        if (!byStream[stream]) byStream[stream] = { stream, dates: [] };
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
          label: streamLabel(b.stream),
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
    } catch (e) { return []; }
  },
};
