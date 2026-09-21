const https = require('https');

function httpGet(urlStr, extraHeaders, cookieStr) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const hdrs = { 'User-Agent': 'Mozilla/5.0', Accept: '*/*', ...(extraHeaders || {}) };
    if (cookieStr) hdrs['Cookie'] = cookieStr;
    const opts = { method: 'GET', hostname: url.hostname, port: 443, path: url.pathname + url.search, headers: hdrs, timeout: 30000 };
    const req = https.request(opts, (resp) => {
      let body = '';
      resp.on('data', c => (body += c));
      resp.on('end', () => resolve({ status: resp.statusCode, body, headers: resp.headers }));
    });
    req.on('error', reject);
    req.setTimeout(30000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

function getCookies(headers) {
  const raw = headers['set-cookie'];
  if (!raw) return {};
  const arr = Array.isArray(raw) ? raw : [raw];
  const jar = {};
  for (const c of arr) {
    const pair = c.split(';')[0].trim();
    const eq = pair.indexOf('=');
    if (eq > 0) jar[pair.substring(0, eq)] = pair.substring(eq + 1);
  }
  return jar;
}

function cookieStr(jar) { return Object.entries(jar).map(([k, v]) => k + '=' + v).join('; '); }

async function main() {
  const BASE = 'https://myselfservice.ne-derbyshire.gov.uk';
  const jar = {};
  const r0 = await httpGet(BASE + '/');
  Object.assign(jar, getCookies(r0.headers));

  console.log('=== Fetch achieveforms-render.js ===');
  const rr = await httpGet(BASE + '/js/FS/build/src/achieveforms-render.js', {}, cookieStr(jar));
  console.log('Status:', rr.status, 'Length:', rr.body.length);

  if (rr.status === 200) {
    const content = rr.body;

    console.log('\n=== Search for form_uri or definition.json ===');
    const defMatches = content.match(/form_uri[^'";\n]{0,200}|definition\.json[^'";\n]{0,200}/g);
    if (defMatches) console.log('Found:', [...new Set(defMatches)].join('\n'));
    else console.log('Not found');

    console.log('\n=== Search for AF-Process or AF-Stage ===');
    const procMatches = content.match(/AF-(?:Process|Stage)-[a-f0-9-]+/g);
    if (procMatches) console.log('Found:', [...new Set(procMatches)].join('\n'));
    else console.log('Not found');

    console.log('\n=== Search for service URL patterns ===');
    const serviceMatches = content.match(/\/service\/[^'";\n\s]+/g);
    if (serviceMatches) console.log('Found:', [...new Set(serviceMatches)].join('\n'));
    else console.log('Not found');

    console.log('\n=== Search for runLookup or apibroker ===');
    const apiMatches = content.match(/runLookup|apibroker/g);
    if (apiMatches) console.log('Found:', apiMatches.length, 'references');
    else console.log('Not found');
  }

  console.log('\n=== Try the bin-day service with different path formats ===');
  const paths = [
    '/service/Check_your_Bin_Day',
    '/en/service/Check_your_Bin_Day',
    '/service/Check_your_Bin_Day?accept=yes',
    '/service/Bins___view_your_waste_collection_calendar',
    '/service/Bin_collection_dates',
    '/service/Bins',
    '/service/Waste_and_recycling',
    '/service/Waste_Collection',
    '/service/my_bin_collection_schedule',
  ];
  for (const p of paths) {
    try {
      const rp = await httpGet(BASE + p, { Referer: BASE + '/' }, cookieStr(jar));
      const hasIframe = rp.body.includes('fillform-frame');
      const hasAF = rp.body.includes('AchieveForms') || rp.body.includes('achieveforms');
      const hasFormUri = rp.body.includes('form_uri');
      console.log(p + ': status=' + rp.status + ' iframe=' + hasIframe + ' AF=' + hasAF + ' formUri=' + hasFormUri + ' len=' + rp.body.length);
      if (hasFormUri) {
        const uriMatch = rp.body.match(/form_uri=([^&"'\s]+)/);
        console.log('  form_uri:', uriMatch ? uriMatch[1] : 'parse error');
      }
      if (rp.body.includes('AF-Process') || rp.body.includes('AF-Stage')) {
        const afMatch = rp.body.match(/AF-(?:Process|Stage)-[a-f0-9-]+/g);
        console.log('  AF IDs:', afMatch ? [...new Set(afMatch)].join(', ') : 'none');
      }
    } catch (e) {
      console.log(p + ': error=' + e.message);
    }
  }

  console.log('\nDone');
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
