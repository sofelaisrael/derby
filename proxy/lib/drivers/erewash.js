const { httpGet, httpPost, cookieJarFrom, cookieHeader, encodeForm } = require('./shared');

const PAGE_URL = 'https://www.erewash.gov.uk/bins-and-recycling/when-my-bin-day';
const ADDRESS_LOOKUP_URL = `${PAGE_URL}?ajax_form=1`;
const COLLECTION_DATES_URL = 'https://www.erewash.gov.uk/bbd-whitespace/one-year-collection-dates-without-christmas';
const FORM_ID = 'bbd_whitespace_bbd_whitespace_address_search';
const UPRN_RE = /^\d+$/;

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

function pad2(n) {
  return String(n).padStart(2, '0');
}

function todayIso() {
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function isoDayOfWeek(isoDate) {
  const day = new Date(`${isoDate}T00:00:00Z`).getUTCDay();
  return day === 0 ? 7 : day;
}

function isoEpochDay(isoDate) {
  return Date.parse(`${isoDate}T00:00:00Z`) / 86400000;
}

function deriveFrequency(isoDates) {
  if (isoDates.length < 2) return null;
  const counts = {};
  for (let i = 1; i < isoDates.length; i++) {
    const gap = isoEpochDay(isoDates[i]) - isoEpochDay(isoDates[i - 1]);
    if (!(gap > 0)) continue;
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

function extractBuildId(html) {
  const m = html.match(/name="form_build_id"[^>]*value="([^"]+)"/i);
  return m ? m[1] : null;
}

function ajaxInsertedHtml(body) {
  let commands;
  try {
    commands = JSON.parse(body);
  } catch (e) {
    throw Object.assign(new Error('Erewash returned a non-JSON ajax response'), { code: 'PARSE_ERROR' });
  }
  if (!Array.isArray(commands)) {
    throw Object.assign(new Error('Erewash returned an unexpected ajax payload'), { code: 'PARSE_ERROR' });
  }
  let html = '';
  for (const cmd of commands) {
    if (cmd && cmd.command === 'insert' && typeof cmd.data === 'string') html += cmd.data;
  }
  return html;
}

function parseAddressOptions(html) {
  const results = [];
  const re = /<option\s+value="(\d+)"[^>]*>([^<]*)<\/option>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    const uprn = m[1];
    const label = m[2].trim();
    if (uprn === '0' || !label) continue;
    results.push({ uprn, label });
  }
  return results;
}

function parseCollectionDates(commands) {
  const months = [];
  for (const cmd of commands) {
    const raw = cmd && cmd.command === 'settings' && cmd.settings && cmd.settings.collection_dates;
    if (Array.isArray(raw)) months.push(raw);
    else if (raw && typeof raw === 'object') months.push(...Object.values(raw));
  }
  const entries = [];
  for (const month of months) {
    if (!Array.isArray(month)) continue;
    for (const item of month) {
      if (!item || typeof item !== 'object') continue;
      const date = typeof item.date === 'string' ? item.date.trim() : '';
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
      const stream = SERVICE_MAP[item['service-identifier']];
      if (!stream) continue;
      entries.push({ date, stream });
    }
  }
  return entries;
}

function buildCollections(entries) {
  const today = todayIso();
  const buckets = {};
  for (const entry of entries) {
    if (!buckets[entry.stream]) buckets[entry.stream] = new Set();
    buckets[entry.stream].add(entry.date);
  }
  const results = [];
  for (const stream of Object.keys(buckets)) {
    const listed = [...buckets[stream]].sort();
    const upcoming = listed.filter(date => date >= today);
    if (upcoming.length === 0) continue;
    const anchor = upcoming[0];
    results.push({
      stream,
      dayOfWeek: isoDayOfWeek(anchor),
      frequency: deriveFrequency(listed),
      anchorDate: anchor,
      nextCollections: upcoming.map(date => ({
        date,
        stream,
        label: LABELS[stream] || stream,
      })),
    });
  }
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

      const cookies = cookieHeader(cookieJarFrom(pageRes.headers));
      const formBuildId = extractBuildId(pageRes.body);
      if (!formBuildId) {
        throw Object.assign(new Error('Could not read form_build_id from the Erewash address form'), { code: 'PARSE_ERROR' });
      }

      const body = encodeForm({
        postcode: normalized,
        link_uri: 'entity:node/646',
        link_text: 'View the calendar',
        form_build_id: formBuildId,
        form_id: FORM_ID,
        _triggering_element_name: 'postcode',
        op: 'Look up address',
      });

      const res = await httpPost(ADDRESS_LOOKUP_URL, body, {
        Cookie: cookies,
        'X-Requested-With': 'XMLHttpRequest',
      });
      if (res.status !== 200) {
        throw Object.assign(new Error(`Erewash postcode lookup returned ${res.status}`), { code: 'UPSTREAM_ERROR' });
      }

      const addresses = parseAddressOptions(ajaxInsertedHtml(res.body));
      if (addresses.length === 0) {
        console.error('[erewash] lookupAddresses: Erewash returned no addresses for postcode %s', normalized);
      }
      return addresses;
    } catch (e) {
      console.error(`[erewash] lookupAddresses failed for ${normalized}: ${e.message}`);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn || !postcode) return [];

    const target = String(uprn).trim();
    if (!UPRN_RE.test(target)) {
      console.error('[erewash] getCollections: refusing non-numeric uprn %j', uprn);
      return [];
    }

    let commands;
    try {
      const res = await httpGet(`${COLLECTION_DATES_URL}?uprn=${encodeURIComponent(target)}`, {
        Accept: 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      });
      if (res.status !== 200) {
        throw Object.assign(new Error(`Erewash collection calendar returned ${res.status} for uprn ${target}`), { code: 'UPSTREAM_ERROR' });
      }
      try {
        commands = JSON.parse(res.body);
      } catch (e) {
        throw Object.assign(new Error(`Erewash collection calendar returned a non-JSON response for uprn ${target}`), { code: 'PARSE_ERROR' });
      }
      if (!Array.isArray(commands)) {
        throw Object.assign(new Error(`Erewash collection calendar returned an unexpected payload for uprn ${target}`), { code: 'PARSE_ERROR' });
      }
    } catch (e) {
      console.error(`[erewash] getCollections failed for uprn ${target}: ${e.message}`);
      throw e;
    }

    const listedEntries = parseCollectionDates(commands);
    const collections = buildCollections(listedEntries);
    if (collections.length === 0) {
      console.error('[erewash] getCollections: Erewash lists %d collection dates for uprn %s but none are upcoming', listedEntries.length, target);
    }
    return collections;
  },
};
