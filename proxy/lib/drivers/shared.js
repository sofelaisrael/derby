const https = require('https');

const OS_PLACES_API = 'https://api.os.uk/search/places/v1';

function httpGet(urlStr) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      method: 'GET',
      hostname: url.hostname,
      path: url.pathname + url.search,
      headers: { 'User-Agent': 'derby-bin-proxy/1.0', Accept: 'application/json' },
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

async function httpGetRetry(urlStr, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const result = await httpGet(urlStr);
      if (result.status !== 429 && result.status !== 503) return result;
      if (attempt === maxRetries) return result;
    } catch (e) {
      if (attempt === maxRetries) throw e;
    }
    const delay = 500 + Math.random() * 1500 + attempt * 1000;
    await new Promise(r => setTimeout(r, delay));
  }
}

async function lookupAddressesOsPlaces(postcode) {
  const key = process.env.OS_API_KEY;
  if (!key) return [];
  const normalized = (postcode || '').trim().toUpperCase().replace(/\s+/g, '');
  const { status, body } = await httpGet(
    `${OS_PLACES_API}/postcode?postcode=${encodeURIComponent(normalized)}&key=${key}&output_srs=EPSG:4326`
  );
  if (status !== 200) {
    throw Object.assign(new Error(`OS Places API returned ${status}`), { code: 'OS_PLACES_ERROR' });
  }
  const data = JSON.parse(body);
  if (!data.results || !Array.isArray(data.results)) return [];
  return data.results
    .filter(r => r.DPA && r.DPA.UPRN)
    .map(r => ({ uprn: String(r.DPA.UPRN), label: r.DPA.ADDRESS }));
}

function httpPost(urlStr, bodyData, headers) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      method: 'POST',
      hostname: url.hostname,
      port: 443,
      path: url.pathname + url.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json, text/html, */*',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(bodyData),
        ...(headers || {}),
      },
      timeout: 30000,
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

function cookieJarFrom(headers) {
  const jar = {};
  const sc = headers && headers['set-cookie'];
  if (!sc) return jar;
  const arr = Array.isArray(sc) ? sc : [sc];
  for (const c of arr) {
    const part = String(c).split(';')[0];
    const idx = part.indexOf('=');
    if (idx > 0) jar[part.slice(0, idx)] = part.slice(idx + 1);
  }
  return jar;
}

function cookieHeader(jar) {
  return Object.entries(jar).map(([k, v]) => `${k}=${v}`).join('; ');
}

function encodeForm(data) {
  return Object.entries(data)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v || '')}`)
    .join('&');
}

module.exports = { httpGet, httpGetRetry, httpPost, lookupAddressesOsPlaces, cookieJarFrom, cookieHeader, encodeForm };
