const https = require('https');

const SESSION_URL = 'https://www.chesterfield.gov.uk/bins-and-recycling/bin-collections/check-bin-collections.aspx';
const FWUID_URL = 'https://myaccount.chesterfield.gov.uk/anonymous/c/cbc_VE_CollectionDaysLO.app?aura.format=JSON&aura.formatAdapter=LIGHTNING_OUT';
const SEARCH_URL = 'https://myaccount.chesterfield.gov.uk/anonymous/aura?r=2&aura.ApexAction.execute=1';

function httpGet(urlStr) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      method: 'GET', hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', Accept: 'application/json, text/html' },
      timeout: 30000,
      rejectUnauthorized: false,
    };
    const req = https.request(opts, (resp) => {
      if (resp.statusCode >= 300 && resp.statusCode < 400 && resp.headers.location) {
        let loc = resp.headers.location;
        if (loc.startsWith('/')) loc = url.protocol + '//' + url.hostname + loc;
        resolve(httpGet(loc));
        return;
      }
      let body = '';
      resp.on('data', c => body += c);
      resp.on('end', () => resolve({ status: resp.statusCode, body, headers: resp.headers }));
    });
    req.on('error', reject);
    req.setTimeout(30000, () => { req.destroy(new Error('timeout')); });
    req.end();
  });
}

function httpPost(urlStr, bodyData, headers) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      method: 'POST', hostname: url.hostname, port: 443, path: url.pathname + url.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(bodyData),
        ...(headers || {}),
      },
      timeout: 30000,
      rejectUnauthorized: false,
    };
    const req = https.request(opts, (resp) => {
      let body = '';
      resp.on('data', c => body += c);
      resp.on('end', () => resolve({ status: resp.statusCode, body, headers: resp.headers }));
    });
    req.on('error', reject);
    req.setTimeout(30000, () => { req.destroy(new Error('timeout')); });
    if (bodyData) req.write(bodyData);
    req.end();
  });
}

function formatDate(d) {
  if (!d || !(d instanceof Date) || isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function mapChesterfieldType(type) {
  const t = (type || '').toLowerCase();
  if (t.includes('refuse')) return 'general';
  if (t.includes('recycling')) return 'recycling';
  if (t.includes('garden') || t.includes('organic')) return 'garden';
  if (t.includes('food')) return 'food';
  return null;
}

module.exports = {
  id: 'chesterfield',
  slug: 'chesterfield',
  name: 'Chesterfield Borough Council',

  async lookupAddresses(postcode) {
    const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!normalized) return [];
    try {
      await httpGet(SESSION_URL);
      const fwuidResp = await httpGet(FWUID_URL);
      if (fwuidResp.status !== 200) return [];
      let fwuidData;
      try { fwuidData = JSON.parse(fwuidResp.body); } catch (e) { return []; }
      const fwuid = fwuidData.auraConfig && fwuidData.auraConfig.context && fwuidData.auraConfig.context.fwuid;
      if (!fwuid) return [];

      const message = JSON.stringify({
        actions: [{
          id: '4;a',
          descriptor: 'aura://ApexActionController/ACTION$execute',
          callingDescriptor: 'UNKNOWN',
          params: {
            classname: 'CBC_VE_CollectionDays',
            method: 'getAddressListFromPostCode',
            params: { postCode: normalized },
            cacheable: false,
            isContinuation: false,
          },
        }],
      });

      const payload = {
        message,
        'aura.context': JSON.stringify({
          mode: 'PROD',
          fwuid,
          app: 'c:cbc_VE_CollectionDaysLO',
          loaded: fwuidData.auraConfig && fwuidData.auraConfig.context && fwuidData.auraConfig.context.loaded || { 'APPLICATION@markup://c:cbc_VE_CollectionDaysLO': 'pqeNg7kPWCbx1pO8sIjdLA' },
          dn: [],
          globals: {},
          uad: true,
        }),
        'aura.pageURI': '/bins-and-recycling/bin-collections/check-bin-collections.aspx',
        'aura.token': 'null',
      };

      const formBody = Object.entries(payload)
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
        .join('&');

      const r = await httpPost(SEARCH_URL, formBody);
      if (r.status !== 200) return [];

      const rawBody = r.body.replace(/^\/\*/, '').replace(/\*\/$/, '');
      let data;
      try { data = JSON.parse(rawBody); } catch (e) { return []; }

      const rv = data.actions && data.actions[0] &&
        data.actions[0].returnValue && data.actions[0].returnValue.returnValue;
      if (!rv) return [];

      let addresses;
      try { addresses = JSON.parse(rv); } catch (e) { return []; }
      if (!Array.isArray(addresses)) return [];

      return addresses.map(a => ({ uprn: String(a.value), label: a.label }));
    } catch (e) {
      console.error('[chesterfield] lookupAddresses error:', e.message);
      return [];
    }
  },

  async getCollections(uprn, postcode) {
    if (!uprn) return [];
    try {
      await httpGet(SESSION_URL);

      const fwuidResp = await httpGet(FWUID_URL);
      if (fwuidResp.status !== 200) return [];
      let fwuidData;
      try { fwuidData = JSON.parse(fwuidResp.body); } catch (e) { return []; }
      const fwuid = fwuidData.auraConfig && fwuidData.auraConfig.context && fwuidData.auraConfig.context.fwuid;
      if (!fwuid) return [];

      const message = JSON.stringify({
        actions: [{
          id: '4;a',
          descriptor: 'aura://ApexActionController/ACTION$execute',
          callingDescriptor: 'UNKNOWN',
          params: {
            classname: 'CBC_VE_CollectionDays',
            method: 'getServicesByUPRN',
            params: { propertyUprn: String(uprn), executedFrom: 'Main Website' },
            cacheable: false,
            isContinuation: false,
          },
        }],
      });

      const payload = {
        message,
        'aura.context': JSON.stringify({
          mode: 'PROD',
          fwuid,
          app: 'c:cbc_VE_CollectionDaysLO',
          loaded: fwuidData.auraConfig && fwuidData.auraConfig.context && fwuidData.auraConfig.context.loaded || { 'APPLICATION@markup://c:cbc_VE_CollectionDaysLO': 'pqeNg7kPWCbx1pO8sIjdLA' },
          dn: [],
          globals: {},
          uad: true,
        }),
        'aura.pageURI': '/bins-and-recycling/bin-collections/check-bin-collections.aspx',
        'aura.token': 'null',
      };

      const formBody = Object.entries(payload)
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
        .join('&');

      const r = await httpPost(SEARCH_URL, formBody);
      if (r.status !== 200) return [];

      let data;
      try { data = JSON.parse(r.body); } catch (e) { return []; }

      const serviceUnits = data.actions && data.actions[0] &&
        data.actions[0].returnValue && data.actions[0].returnValue.returnValue &&
        data.actions[0].returnValue.returnValue.serviceUnits;
      if (!Array.isArray(serviceUnits)) return [];

      const results = [];
      const seen = new Set();
      for (const unit of serviceUnits) {
        const tasks = unit.serviceTasks;
        if (!Array.isArray(tasks)) continue;
        for (const task of tasks) {
          const wasteType = (task.taskTypeName || '').replace('Collect ', '').trim();
          if (!wasteType) continue;
          const schedules = task.serviceTaskSchedules;
          if (!Array.isArray(schedules)) continue;
          for (const schedule of schedules) {
            const next = schedule.nextInstance;
            if (!next || !next.currentScheduledDate) continue;
            const date = new Date(next.currentScheduledDate);
            if (isNaN(date.getTime())) continue;
            const stream = mapChesterfieldType(wasteType);
            if (!stream) continue;
            const dateStr = formatDate(date);
            const key = `${stream}:${dateStr}`;
            if (seen.has(key)) continue;
            seen.add(key);
            const label = { general: 'Domestic Refuse', recycling: 'Domestic Recycling', garden: 'Domestic Paid Garden', food: 'Domestic Food' }[stream] || wasteType;
            results.push({ stream, date: dateStr, label });
          }
        }
      }

      if (results.length === 0) return [];
      const byStream = {};
      for (const r of results) {
        if (!byStream[r.stream]) byStream[r.stream] = [];
        byStream[r.stream].push(r);
      }

      const final = [];
      for (const [stream, items] of Object.entries(byStream)) {
        items.sort((a, b) => a.date.localeCompare(b.date));
        const anchor = new Date(items[0].date);
        const nextCollections = items.map(i => ({ date: i.date, stream, label: i.label }));
        final.push({
          stream,
          dayOfWeek: anchor.getDay() === 0 ? 7 : anchor.getDay(),
          frequency: items.length > 4 ? 'fortnightly' : 'fortnightly',
          anchorDate: items[0].date,
          nextCollections,
        });
      }
      return final;
    } catch (e) { return []; }
  },
};
