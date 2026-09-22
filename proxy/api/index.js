const http = require('http');
const binsHandler = require('./bins');
const addressesHandler = require('./addresses');
const reportHandler = require('./report');

function parseQuery(urlStr) {
  const q = {};
  try {
    const u = new URL(urlStr, 'http://localhost');
    for (const [k, v] of u.searchParams) q[k] = v;
  } catch (_) {}
  return q;
}

function wrapRes(res) {
  let statusCode = 200;
  const wrapped = Object.create(res);
  wrapped.status = function(code) {
    statusCode = code;
    return wrapped;
  };
  wrapped.json = function(data) {
    if (!res.headersSent) {
      res.writeHead(statusCode, { 'Content-Type': 'application/json' });
    }
    res.end(JSON.stringify(data));
    return wrapped;
  };
  wrapped.end = function(body) {
    if (!res.headersSent) {
      res.writeHead(statusCode);
    }
    res.end(body);
    return wrapped;
  };
  return wrapped;
}

const handlers = {
  '/bins': binsHandler,
  '/addresses': addressesHandler,
  '/report': reportHandler,
  '/debug/ambervalley': async (req, res) => {
    const { httpPost } = require('../lib/drivers/shared');
    const LOOKUP_URL = 'https://info.ambervalley.gov.uk/WebServices/AVBCFeeds/GazetteerJSON.asmx/PropertyLookupFeed';
    const postcode = (req.query && req.query.postcode) || 'DE562AN';
    const results = {};

    try {
      const formData = `srchText=${encodeURIComponent(postcode)}`;
      const r1 = await httpPost(LOOKUP_URL, formData, { 'Content-Type': 'application/x-www-form-urlencoded' });
      results.postFormBody = { status: r1.status, body: r1.body.substring(0, 1000) };
    } catch (e) { results.postFormBody = { error: e.message, code: e.code }; }

    try {
      const r2Url = `${LOOKUP_URL}?srchText=${encodeURIComponent(postcode)}`;
      const { httpGet } = require('../lib/drivers/shared');
      const r2 = await httpGet(r2Url, { Accept: 'application/json' });
      results.getQueryParam = { status: r2.status, body: r2.body.substring(0, 1000) };
    } catch (e) { results.getQueryParam = { error: e.message, code: e.code }; }

    try {
      const { httpPost: httpPost2 } = require('../lib/drivers/shared');
      const r3Url = `${LOOKUP_URL}?srchText=${encodeURIComponent(postcode)}`;
      const r3 = await httpPost2(r3Url, '', { 'Content-Type': 'application/x-www-form-urlencoded' });
      results.postQueryEmptyBody = { status: r3.status, body: r3.body.substring(0, 1000) };
    } catch (e) { results.postQueryEmptyBody = { error: e.message, code: e.code }; }

    try {
      const { httpPost: httpPost3 } = require('../lib/drivers/shared');
      const r4 = await httpPost3(LOOKUP_URL, JSON.stringify({ srchText: postcode }), { 'Content-Type': 'application/json' });
      results.postJsonBody = { status: r4.status, body: r4.body.substring(0, 1000) };
    } catch (e) { results.postJsonBody = { error: e.message, code: e.code }; }

    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json(results);
  },
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const path = url.pathname.replace(/\/+$/, '') || '/';

  if (path === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok', endpoints: ['/bins', '/addresses', '/report', '/debug/ambervalley'] }));
  }

  const handler = handlers[path];
  if (!handler) {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'Not found' }));
  }

  req.query = parseQuery(req.url);
  const wres = wrapRes(res);

  try {
    await handler(req, wres);
  } catch (e) {
    console.error('Handler error:', path, e.message);
    if (!res.headersSent) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
    }
    res.end(JSON.stringify({ error: 'Internal server error' }));
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log('Derby bin proxy listening on port ' + PORT);
});