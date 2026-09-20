const { httpGet, httpPost, encodeForm, cookieJarFrom, cookieHeader, lookupAddressesOsPlaces } = require('./shared');

const FORM_URL = 'https://selfserve.derbyshiredales.gov.uk/renderform?k=9644C066D2168A4C21BCDA351DA2642526359DFF&t=103';
const RENDER_URL = 'https://selfserve.derbyshiredales.gov.uk/RenderForm';

function extractHiddenInputs(html) {
  const inputs = {};
  const re = /<input[^>]*type="hidden"[^>]*>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    const tag = m[0];
    const nameMatch = tag.match(/name="([^"]+)"/i);
    const valueMatch = tag.match(/value="([^"]*?)"/i);
    if (nameMatch) inputs[nameMatch[1]] = valueMatch ? valueMatch[1] : '';
  }
  return inputs;
}

function extractFormFields(html) {
  const fields = [];
  const inputRe = /<input[^>]*>/gi;
  let m;
  while ((m = inputRe.exec(html)) !== null) {
    const tag = m[0];
    const nameMatch = tag.match(/name="([^"]*)"/i);
    const valueMatch = tag.match(/value="([^"]*?)"/i);
    if (nameMatch && nameMatch[1]) {
      fields.push({ name: nameMatch[1], value: valueMatch ? valueMatch[1] : '' });
    }
  }
  return fields;
}

function parseRows(html) {
  const collections = [];
  const rowRe = /<div[^>]*class="[^"]*row[^"]*"[^>]*style="[^"]*padding-left[^"]*"[^>]*>([\s\S]*?)<\/div>\s*(?=<div[^>]*class="[^"]*row|<\/div>\s*<\/div>)/gi;
  let m;
  while ((m = rowRe.exec(html)) !== null) {
    const rowHtml = m[1];
    const dateCol = rowHtml.match(/<div[^>]*class="[^"]*col-sm-5[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
    const typeCol = rowHtml.match(/<div[^>]*class="[^"]*col-sm-6[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
    if (!dateCol || !typeCol) continue;
    const rawDate = dateCol[1].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
    const rawType = typeCol[1].replace(/<[^>]+>/g, '').trim();
    const dateMatch = rawDate.match(/(\w+)\s+(\d{1,2})\s+(\w+),?\s+(\d{4})/);
    if (!dateMatch) continue;
    const months = { January: 0, February: 1, March: 2, April: 3, May: 4, June: 5, July: 6, August: 7, September: 8, October: 9, November: 10, December: 11 };
    const day = parseInt(dateMatch[2]);
    const month = months[dateMatch[3]];
    const year = parseInt(dateMatch[4]);
    if (isNaN(day) || month === undefined || isNaN(year)) continue;
    const date = new Date(year, month, day);
    if (isNaN(date.getTime())) continue;
    const lower = rawType.toLowerCase();
    let stream = null;
    if (lower.includes('domestic')) stream = 'general';
    else if (lower.includes('recycling')) stream = 'recycling';
    else if (lower.includes('food')) stream = 'food';
    else if (lower.includes('garden')) stream = 'garden';
    if (!stream) continue;
    collections.push({ date, stream });
  }
  return collections;
}

function formatDate(d) {
  if (!d || !(d instanceof Date) || isNaN(d.getTime())) return null;
  const y = d.getFullYear();
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

module.exports = {
  id: 'derbyshiredales',
  slug: 'derbyshiredales',
  name: 'Derbyshire Dales District Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try { return await lookupAddressesOsPlaces(normalized); } catch (e) { return []; }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const r1 = await httpGet(FORM_URL);
      if (r1.status !== 200) throw Object.assign(new Error(`Form page returned ${r1.status}`), { code: 'UPSTREAM_ERROR' });

      const jar = cookieJarFrom(r1.headers);
      const formFields = extractFormFields(r1.body);
      const formInputs = {};
      for (const f of formFields) {
        formInputs[f.name] = f.value;
      }

      if (!formInputs.__RequestVerificationToken || !formInputs.FormGuid) return [];

      const payload = {};
      for (const f of formFields) {
        if (f.name === 'FF2924') {
          payload[f.name] = uprn;
        } else if (f.name === 'FF2924-text') {
          payload[f.name] = '';
        } else if (f.name) {
          payload[f.name] = f.value;
        }
      }

      const r2 = await httpPost(RENDER_URL, encodeForm(payload), { Cookie: cookieHeader(jar) });
      if (r2.status !== 200) return [];

      const collections = parseRows(r2.body);
      if (collections.length === 0) return [];

      const byStream = {};
      for (const c of collections) {
        if (!byStream[c.stream]) byStream[c.stream] = [];
        const dateStr = formatDate(c.date);
        if (byStream[c.stream].some(d => formatDate(d) === dateStr)) continue;
        byStream[c.stream].push(c.date);
      }

      const results = [];
      for (const [stream, dates] of Object.entries(byStream)) {
        if (dates.length === 0) continue;
        dates.sort((a, b) => a - b);
        const anchor = dates[0];
        const freq = deriveFrequency(dates);
        const label = { general: 'Domestic Waste', recycling: 'Recycling Waste', food: 'Food Waste', garden: 'Garden Waste' }[stream] || stream;
        const nextCollections = dates.map(d => ({ date: formatDate(d), stream, label }));
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
