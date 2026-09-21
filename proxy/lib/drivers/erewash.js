const { lookupAddressesOsPlaces, httpGet } = require('./shared');

const SERVICE_MAP = {
  'domestic-waste-collection-service': 'general',
  'recycling-collection-service': 'recycling',
  'garden-waste-collection-service': 'garden',
  'food-waste-collection-service': 'food',
};

const LABELS = {
  general: 'General Waste',
  recycling: 'Recycling',
  garden: 'Garden Waste',
  food: 'Food Waste',
};

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

module.exports = {
  id: 'erewash',
  slug: 'erewash',
  name: 'Erewash Borough Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try {
      return await lookupAddressesOsPlaces(normalized);
    } catch (e) {
      console.error(`erewash lookupAddresses error: ${e.message}`);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      const url = `https://www.erewash.gov.uk/bbd-whitespace/one-year-collection-dates?uprn=${encodeURIComponent(uprn)}&_wrapper_format=drupal_ajax`;
      const result = await httpGet(url, {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      });
      if (result.status !== 200) {
        throw Object.assign(new Error(`Erewash API returned ${result.status}`), { code: 'UPSTREAM_ERROR' });
      }

      let data;
      try {
        data = JSON.parse(result.body);
      } catch (e) {
        throw Object.assign(new Error('Invalid JSON from Erewash API'), { code: 'PARSE_ERROR' });
      }

      if (Array.isArray(data)) {
        const settingsEntry = data.find(d => d && d.settings && d.settings.collection_dates);
        if (settingsEntry) {
          const settings = settingsEntry.settings.collection_dates;
          if (settings && typeof settings === 'object') {
            const byStream = {};

            for (const key of Object.keys(settings)) {
              const collections = settings[key];
              if (!Array.isArray(collections)) continue;

              for (const item of collections) {
                const stream = SERVICE_MAP[item['service-identifier']];
                if (!stream) continue;
                if (!item.timestamp) continue;

                const date = new Date(item.timestamp * 1000);
                if (isNaN(date.getTime())) continue;

                if (!byStream[stream]) byStream[stream] = { stream, dates: [] };
                byStream[stream].dates.push(date);
              }
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
          }
        }
      }

      if (typeof data === 'object' && data !== null && !Array.isArray(data)) {
        const collections = data.collection_dates || data.dates || data.collections;
        if (collections && typeof collections === 'object') {
          const byStream = {};
          const items = Array.isArray(collections) ? collections : Object.values(collections).flat();
          for (const item of items) {
            if (!item) continue;
            const stream = SERVICE_MAP[item['service-identifier'] || item.service || item.type];
            if (!stream) continue;
            const ts = item.timestamp || item.date || item.collection_date;
            if (!ts) continue;
            const date = new Date(typeof ts === 'number' ? ts * 1000 : ts);
            if (isNaN(date.getTime())) continue;
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
        }
      }

      return [];
    } catch (e) {
      console.error(`erewash getCollections error for uprn ${uprn}: ${e.message}`);
      return [];
    }
  },
};
