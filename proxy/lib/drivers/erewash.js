const { httpGet, httpPost, cookieJarFrom, cookieHeader, encodeForm } = require('./shared');

const SERVICE_MAP = {
  'domestic-waste-collection-service': 'general',
  'recycling-collection-service': 'recycling',
  'garden-waste-collection-service': 'garden',
  'food-collection-service': 'food',
};

const LABELS = {
  general: 'General Waste',
  recycling: 'Recycling',
  garden: 'Garden Waste',
  food: 'Food Waste',
};

const MONTHS = {
  January: 0, February: 1, March: 2, April: 3, May: 4, June: 5,
  July: 6, August: 7, September: 8, October: 9, November: 10, December: 11,
};

const AJAX_URL = 'https://www.erewash.gov.uk/bins-and-recycling/when-my-bin-day?ajax_form=1&_wrapper_format=drupal_ajax';
const PAGE_URL = 'https://www.erewash.gov.uk/bins-and-recycling/when-my-bin-day';

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

function extractBuildId(html) {
  const m = html.match(/name="form_build_id"[^>]*value="([^"]+)"/i);
  return m ? m[1] : null;
}

function parsePostcodeOptions(html) {
  const results = [];
  const re = /<option\s+value="(\d+)">\s*([^<]+)<\/option>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    results.push({ uprn: m[1], label: m[2].trim() });
  }
  return results;
}

function parseCollectionTable(html) {
  const results = [];
  const rowRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let rowMatch;
  while ((rowMatch = rowRe.exec(html)) !== null) {
    const rowHtml = rowMatch[1];
    const cellRe = /<td[^>]*class="bin-service\s+([^"]+)"[^>]*>([^<]+)<\/td>/i;
    const cellMatch = rowHtml.match(cellRe);
    if (!cellMatch) continue;

    const classes = cellMatch[1];
    let stream = null;
    for (const [key, val] of Object.entries(SERVICE_MAP)) {
      if (classes.includes(key)) { stream = val; break; }
    }
    if (!stream) continue;

    const dayRe = /<td[^>]*class="bin-service-day"[^>]*>([^<]+)<\/td>/i;
    const dateRe = /<td[^>]*class="bin-service-date"[^>]*>([^<]+)<\/td>/i;
    const dayMatch = rowHtml.match(dayRe);
    const dateMatch = rowHtml.match(dateRe);
    if (!dayMatch || !dateMatch) continue;

    const dayStr = dayMatch[1].trim();
    const dateStr = dateMatch[1].trim();

    const dateParts = dateStr.match(/(\d{1,2})\s+(\w+)/);
    if (!dateParts) continue;

    const day = parseInt(dateParts[1]);
    const monthName = dateParts[2];
    const month = MONTHS[monthName];
    if (month === undefined) continue;

    const now = new Date();
    let year = now.getFullYear();
    let date = new Date(year, month, day);
    if (date < now) {
      date = new Date(year + 1, month, day);
    }

    results.push({ stream, dayOfWeek: dayStr, date });
  }
  if (results.length === 0) console.error('[erewash] parseCollectionTable: no rows found in response');
  return results;
}

module.exports = {
  id: 'erewash',
  slug: 'erewash',
  name: 'Erewash Borough Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try {
      const pageRes = await httpGet(PAGE_URL);
      if (pageRes.status !== 200) {
        throw Object.assign(new Error(`Erewash page returned ${pageRes.status}`), { code: 'UPSTREAM_ERROR' });
      }

      const jar = cookieJarFrom(pageRes.headers);
      const cookies = cookieHeader(jar);
      const formBuildId = extractBuildId(pageRes.body);
      if (!formBuildId) {
        throw Object.assign(new Error('Could not extract form_build_id from Erewash page'), { code: 'PARSE_ERROR' });
      }

      const postcodeBody = encodeForm({
        postcode: normalized,
        link_uri: 'entity:node/646',
        link_text: 'View the calendar',
        form_build_id: formBuildId,
        form_id: 'bbd_whitespace_bbd_whitespace_address_search',
        _triggering_element_name: 'postcode',
        _drupal_ajax: '1',
        op: 'Look up address',
      });

      const postcodeRes = await httpPost(AJAX_URL, postcodeBody, {
        'Cookie': cookies,
        'X-Requested-With': 'XMLHttpRequest',
      });
      if (postcodeRes.status !== 200) {
        throw Object.assign(new Error(`Erewash postcode lookup returned ${postcodeRes.status}`), { code: 'UPSTREAM_ERROR' });
      }

      let postcodeData;
      try {
        postcodeData = JSON.parse(postcodeRes.body);
      } catch (e) {
        throw Object.assign(new Error('Invalid JSON from Erewash postcode lookup'), { code: 'PARSE_ERROR' });
      }

      if (!Array.isArray(postcodeData)) {
        throw Object.assign(new Error('Expected array from Erewash postcode lookup'), { code: 'PARSE_ERROR' });
      }

      let addressHtml = '';
      for (const cmd of postcodeData) {
        if (cmd.command === 'insert' && cmd.data) {
          addressHtml += cmd.data;
        }
      }

      return parsePostcodeOptions(addressHtml);
    } catch (e) {
      console.error(`erewash lookupAddresses error: ${e.message}`);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn || !postcode) return [];

    try {
      const pageRes = await httpGet(PAGE_URL);
      if (pageRes.status !== 200) {
        throw Object.assign(new Error(`Erewash page returned ${pageRes.status}`), { code: 'UPSTREAM_ERROR' });
      }

      const jar = cookieJarFrom(pageRes.headers);
      let cookies = cookieHeader(jar);
      const formBuildId = extractBuildId(pageRes.body);
      console.error('[erewash] step1 homepage: status=%d form_build_id=%s cookies=%s', pageRes.status, formBuildId || 'NONE', cookies || 'NONE');
      if (!formBuildId) {
        throw Object.assign(new Error('Could not extract form_build_id from Erewash page'), { code: 'PARSE_ERROR' });
      }

      const postcodeBody = encodeForm({
        postcode: postcode,
        link_uri: 'entity:node/646',
        link_text: 'View the calendar',
        form_build_id: formBuildId,
        form_id: 'bbd_whitespace_bbd_whitespace_address_search',
        _triggering_element_name: 'postcode',
        _drupal_ajax: '1',
        op: 'Look up address',
      });

      const postcodeRes = await httpPost(AJAX_URL, postcodeBody, {
        'Cookie': cookies,
        'X-Requested-With': 'XMLHttpRequest',
      });
      if (postcodeRes.status !== 200) {
        throw Object.assign(new Error(`Erewash postcode lookup returned ${postcodeRes.status}`), { code: 'UPSTREAM_ERROR' });
      }

      const jar2 = cookieJarFrom(postcodeRes.headers);
      const mergedJar = { ...jar, ...jar2 };
      cookies = cookieHeader(mergedJar);

      let postcodeData;
      try {
        postcodeData = JSON.parse(postcodeRes.body);
      } catch (e) {
        throw Object.assign(new Error('Invalid JSON from Erewash postcode lookup'), { code: 'PARSE_ERROR' });
      }

      if (!Array.isArray(postcodeData)) {
        throw Object.assign(new Error('Expected array from Erewash postcode lookup'), { code: 'PARSE_ERROR' });
      }

      let nextBuildId = null;
      let addressHtml = '';
      for (const cmd of postcodeData) {
        if (cmd.command === 'update_build_id' && cmd.new) {
          nextBuildId = cmd.new;
        }
        if (cmd.command === 'insert' && cmd.data) {
          addressHtml += cmd.data;
        }
      }

      if (!nextBuildId) {
        throw Object.assign(new Error('Could not extract next form_build_id from postcode response'), { code: 'PARSE_ERROR' });
      }

      const matchedAddr = parsePostcodeOptions(addressHtml);
      const target = matchedAddr.find(a => a.uprn === String(uprn));
      console.error('[erewash] step2 postcode: status=%d addresses=%d uprn_found=%s next_build_id=%s', postcodeRes.status, matchedAddr.length, !!target, nextBuildId || 'NONE');
      if (!target) {
        throw Object.assign(new Error(`UPRN ${uprn} not found in postcode response`), { code: 'UPRN_NOT_FOUND' });
      }

      const uprnBody = encodeForm({
        addresses: String(uprn),
        postcode: postcode,
        link_uri: 'entity:node/646',
        link_text: 'View the calendar',
        form_build_id: nextBuildId,
        form_id: 'bbd_whitespace_bbd_whitespace_address_search',
        _triggering_element_name: 'addresses',
        _drupal_ajax: '1',
        op: 'Look up address',
      });

      console.error('[erewash] step3 uprn post: uprn=%s build_id=%s', uprn, nextBuildId);

      const uprnRes = await httpPost(AJAX_URL, uprnBody, {
        'Cookie': cookies,
        'X-Requested-With': 'XMLHttpRequest',
      });
      if (uprnRes.status !== 200) {
        throw Object.assign(new Error(`Erewash UPRN lookup returned ${uprnRes.status}`), { code: 'UPSTREAM_ERROR' });
      }

      let uprnData;
      try {
        uprnData = JSON.parse(uprnRes.body);
      } catch (e) {
        throw Object.assign(new Error('Invalid JSON from Erewash UPRN lookup'), { code: 'PARSE_ERROR' });
      }

      if (!Array.isArray(uprnData)) {
        throw Object.assign(new Error('Expected array from Erewash UPRN lookup'), { code: 'PARSE_ERROR' });
      }

      let collectionHtml = '';
      for (const cmd of uprnData) {
        if (cmd.command === 'insert' && cmd.data) {
          collectionHtml += cmd.data;
        }
      }

      const rows = parseCollectionTable(collectionHtml);
      console.error('[erewash] step4 collections: status=%d parsed=%d rows=%d', uprnRes.status, uprnData.length, rows.length);
      if (rows.length === 0) return [];

      const byStream = {};
      for (const row of rows) {
        if (!byStream[row.stream]) byStream[row.stream] = { stream: row.stream, dates: [] };
        byStream[row.stream].dates.push(row.date);
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
      console.error('[erewash] getCollections error:', e.message);
      throw e;
    }
  },
};
