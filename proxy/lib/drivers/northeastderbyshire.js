const { httpGet } = require('./shared');

const PAGE_URL = 'https://www.ne-derbyshire.gov.uk/bins-and-recycling/bin-collection-dates';
const MONTHS = { january: 0, february: 1, march: 2, april: 3, may: 4, june: 5, july: 6, august: 7, september: 8, october: 9, november: 10, december: 11 };
const NORTH_TOWNS = ['apperknowle', 'arkwright', 'barlow', 'brampton', 'calow', 'coal aston', 'cutthorpe', 'dronfield', 'duckmanton', 'eckington', 'holmesfield', 'killamarsh', 'marsh lane', 'renishaw', 'ridgeway', 'sutton (rural', 'temple normanton (rural', 'unstone', 'wadshelf'];
const SOUTH_TOWNS = ['ashover', 'brackenfield', 'clay cross', 'grassmoor', 'hasland', 'heath', 'higham', 'holmewood', 'holymoorside', 'morton', 'north wingfield', 'pilsley', 'shirland', 'stretton', 'sutton', 'temple normanton', 'tupton', 'walton', 'wessington', 'wingerworth', 'winsick'];

function determineArea(town) {
  if (!town) return 'north';
  const lower = town.toLowerCase();
  for (const t of NORTH_TOWNS) {
    if (lower.includes(t)) return 'north';
  }
  for (const t of SOUTH_TOWNS) {
    if (lower.includes(t)) return 'south';
  }
  return 'north';
}

function formatTownsForDisplay(towns) {
  return towns
    .map(t => {
      let s = t;
      let open = 0;
      for (const ch of s) { if (ch === '(') open++; else if (ch === ')') open--; }
      if (open > 0) s += ')'.repeat(open);
      return s.replace(/(^|\s)([a-z])/g, (_, pre, ch) => pre + ch.toUpperCase());
    })
    .join(', ');
}

function stripTags(html) {
  return html.replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
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

function mapBinTypes(text) {
  const lower = text.toLowerCase();
  if (lower.includes('no collection')) return [];
  const streams = [];
  if (lower.includes('black bin') || (lower.includes('black') && lower.includes('bin'))) streams.push('general');
  if (lower.includes('burgundy') || lower.includes('green bin')) streams.push('recycling');
  if (lower.includes('food caddy')) streams.push('food');
  return [...new Set(streams)];
}

function parseCollectionEntry(text, currentYear) {
  const dayRe = /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(\d{1,2})(?:st|nd|rd|th)/;
  const dm = text.match(dayRe);
  if (!dm) return null;
  const day = parseInt(dm[2]);
  const restAfterDay = text.substring(text.indexOf(dm[0]) + dm[0].length);
  const monthRe = /(?:to\s+(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+\d{1,2}(?:st|nd|rd|th)\s+)?(January|February|March|April|May|June|July|August|September|October|November|December)/i;
  const mm = restAfterDay.match(monthRe);
  if (!mm) return null;
  const monthName = mm[1].toLowerCase();
  const month = MONTHS[monthName];
  if (month === undefined) return null;
  const yearRe = /(\d{4})/;
  const ym = restAfterDay.match(yearRe);
  let year = ym ? parseInt(ym[1]) : currentYear;
  if (!year) return null;
  const date = new Date(year, month, day);
  if (isNaN(date.getTime())) return null;
  return date;
}

function parseSectionHtml(sectionHtml) {
  const entries = [];
  let currentYear = 2026;
  const tokenRe = /(<h4[^>]*>[\s\S]*?<\/h4>|<strong[^>]*>[\s\S]*?<\/strong>|<(?:p|li)[^>]*>[\s\S]*?<\/(?:p|li)>)/gi;
  let token;
  while ((token = tokenRe.exec(sectionHtml)) !== null) {
    const tag = token[0];
    const text = stripTags(tag);
    if (!text) continue;
    const isH4 = /^<h4/i.test(tag);
    const isStrong = /^<strong/i.test(tag);
    if (isH4) {
      const h4Year = text.match(/(\d{4})/);
      if (h4Year) currentYear = parseInt(h4Year[1]);
      continue;
    }
    if (isStrong) {
      const strongMatch = text.match(/(January|February|March|April|May|June|July|August|September|October|November|December)\s+[''']?(\d{2,4})/i);
      if (strongMatch) {
        let yr = parseInt(strongMatch[2]);
        if (yr < 100) yr += 2000;
        currentYear = yr;
      }
      continue;
    }
    if (text.toLowerCase().includes('no collection')) continue;
    if (!text.match(/(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+\d{1,2}/)) continue;
    const date = parseCollectionEntry(text, currentYear);
    if (!date) continue;
    const streams = mapBinTypes(text);
    if (streams.length === 0) continue;
    entries.push({ date, streams });
  }
  return entries;
}

module.exports = {
  id: 'northeastderbyshire',
  slug: 'northeastderbyshire',
  name: 'North East Derbyshire District Council',
  calendarBased: true,

  async lookupAddresses(postcode) {
    return [
      { uprn: 'calendar-a', label: `Calendar A - The North: ${formatTownsForDisplay(NORTH_TOWNS)}`, town: 'The North' },
      { uprn: 'calendar-b', label: `Calendar B - The South: ${formatTownsForDisplay(SOUTH_TOWNS)}`, town: 'The South' },
    ];
  },

  async getCollections(uprn, postcode) {
    const isCalendar = uprn === 'calendar-a' || uprn === 'calendar-b';
    if (!postcode && !isCalendar) return [];
    try {
      let area;
      if (uprn === 'calendar-a') {
        area = 'north';
      } else if (uprn === 'calendar-b') {
        area = 'south';
      } else {
        const normalized = postcode.trim().toUpperCase().replace(/\s+/g, '');
        let town = '';
        try {
          const key = process.env.OS_API_KEY;
          if (key) {
            const { status, body } = await httpGet(
              `https://api.os.uk/search/places/v1/postcode?postcode=${encodeURIComponent(normalized)}&key=${key}&output_srs=EPSG:4326`
            );
            if (status === 200) {
              const data = JSON.parse(body);
              if (data.results && data.results.length > 0 && data.results[0].DPA) {
                town = data.results[0].DPA.TOWN_NAME || data.results[0].DPA.LOCALITY || '';
              }
            }
          }
        } catch (e) {}

        area = determineArea(town);
      }

      const r = await httpGet(PAGE_URL);
      if (r.status !== 200) return [];
      const html = r.body;

      const northId = 'rlta-panel-view-the-north-area-upcoming-collection-dates';
      const southId = 'rlta-panel-view-the-south-area-upcoming-collection-dates';
      const northStart = html.indexOf(northId);
      const southStart = html.indexOf(southId);

      if (northStart === -1 && southStart === -1) return [];

      let sectionHtml = '';

      if (area === 'south' && southStart !== -1) {
        const panelStart = html.indexOf('>', southStart) + 1;
        const calendarEnd = html.indexOf('<h2', panelStart);
        sectionHtml = html.substring(panelStart, calendarEnd > panelStart ? calendarEnd : html.length);
      } else if (northStart !== -1) {
        const panelStart = html.indexOf('>', northStart) + 1;
        const nextSectionStart = southStart !== -1 ? southStart : html.indexOf('Which calendar do I use');
        sectionHtml = html.substring(panelStart, nextSectionStart > panelStart ? nextSectionStart : html.length);
      } else if (southStart !== -1) {
        const panelStart = html.indexOf('>', southStart) + 1;
        const calendarEnd = html.indexOf('<h2', panelStart);
        sectionHtml = html.substring(panelStart, calendarEnd > panelStart ? calendarEnd : html.length);
      }

      if (!sectionHtml) return [];

      const allEntries = parseSectionHtml(sectionHtml);

      const byStream = {};
      const seen = new Set();
      for (const entry of allEntries) {
        for (const stream of entry.streams) {
          const key = `${stream}:${formatDate(entry.date)}`;
          if (seen.has(key)) continue;
          seen.add(key);
          if (!byStream[stream]) byStream[stream] = [];
          byStream[stream].push(entry.date);
        }
      }

      const now = new Date();
      const results = [];
      for (const [stream, dates] of Object.entries(byStream)) {
        dates.sort((a, b) => a - b);
        const valid = dates.filter(d => d >= now);
        if (valid.length === 0) continue;
        const anchor = valid[0];
        const freq = deriveFrequency(valid);
        const label = { general: 'General Waste', recycling: 'Recycling', food: 'Food Waste' }[stream] || stream;
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
