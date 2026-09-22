const http = require('http');
const binsHandler = require('./bins');
const addressesHandler = require('./addresses');
const reportHandler = require('./report');
const drivers = require('../lib/drivers');

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

const diagHandler = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  const driver = drivers.getDriver('chesterfield');
  try {
    const addrs = await driver.lookupAddresses('S40 3JL');
    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json({ addresses: addrs, count: addrs.length });
  } catch (e) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(500).json({ error: e.message, stack: e.stack });
  }
};

const handlers = {
  '/bins': binsHandler,
  '/addresses': addressesHandler,
  '/report': reportHandler,
  '/diagnose': diagHandler,
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const path = url.pathname.replace(/\/+$/, '') || '/';

  if (path === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok', endpoints: ['/bins', '/addresses', '/report', '/diagnose'] }));
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