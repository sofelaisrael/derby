const assert = require('assert');
let failures = 0;
let passes = 0;

function describe(name, fn) { console.log(`\n  ${name}`); fn(); }
function it(name, fn) {
  try { fn(); passes++; console.log(`    \u2713 ${name}`); }
  catch(e) { failures++; console.log(`    \u2717 ${name}`); console.log(`      ${e.message}`); }
}

function itAsync(name, fn) {
  return fn().then(() => { passes++; console.log(`    \u2713 ${name}`); })
    .catch(e => { failures++; console.log(`    \u2717 ${name}`); console.log(`      ${e.message}`); });
}

async function run() {
  describe('Driver Registry', () => {
    const { listDrivers, getDriver } = require('../lib/drivers');

    const drivers = listDrivers();

    it('listDrivers returns array with length >= 9', () => {
      assert.ok(Array.isArray(drivers), 'should be an array');
      assert.ok(drivers.length >= 9, `expected >= 9, got ${drivers.length}`);
    });

    it('each item has id, name, slug properties', () => {
      for (const d of drivers) {
        assert.ok(d.id, `missing id on ${JSON.stringify(d)}`);
        assert.ok(d.name, `missing name on ${JSON.stringify(d)}`);
        assert.ok(d.slug, `missing slug on ${JSON.stringify(d)}`);
      }
    });

    it('derby is in the list', () => {
      const d = getDriver('derby');
      assert.ok(d, 'derby driver not found');
      assert.strictEqual(d.id, 'derby');
      assert.strictEqual(d.name, 'Derby City Council');
    });

    it('erewash is in the list', () => {
      const d = getDriver('erewash');
      assert.ok(d, 'erewash driver not found');
      assert.strictEqual(d.id, 'erewash');
      assert.strictEqual(d.name, 'Erewash Borough Council');
    });

    it('ambervalley is in the list', () => {
      const d = getDriver('ambervalley');
      assert.ok(d, 'ambervalley driver not found');
      assert.strictEqual(d.name, 'Amber Valley Borough Council');
    });

    it('highpeak is in the list', () => {
      const d = getDriver('highpeak');
      assert.ok(d, 'highpeak driver not found');
      assert.strictEqual(d.name, 'High Peak Borough Council');
    });

    it('derbyshiredales is in the list', () => {
      const d = getDriver('derbyshiredales');
      assert.ok(d, 'derbyshiredales driver not found');
      assert.strictEqual(d.name, 'Derbyshire Dales District Council');
    });

    it('bolsover is in the list', () => {
      const d = getDriver('bolsover');
      assert.ok(d, 'bolsover driver not found');
      assert.strictEqual(d.name, 'Bolsover District Council');
    });

    it('chesterfield is in the list', () => {
      const d = getDriver('chesterfield');
      assert.ok(d, 'chesterfield driver not found');
      assert.strictEqual(d.name, 'Chesterfield Borough Council');
    });

    it('southderbyshire is in the list', () => {
      const d = getDriver('southderbyshire');
      assert.ok(d, 'southderbyshire driver not found');
      assert.strictEqual(d.name, 'South Derbyshire District Council');
    });

    it('northeastderbyshire is in the list', () => {
      const d = getDriver('northeastderbyshire');
      assert.ok(d, 'northeastderbyshire driver not found');
      assert.strictEqual(d.name, 'North East Derbyshire District Council');
    });

    it('getDriver("Derby City Council") returns truthy (name lookup)', () => {
      assert.ok(getDriver('Derby City Council'));
    });

    it('getDriver("Erewash Borough Council") returns truthy (name lookup)', () => {
      assert.ok(getDriver('Erewash Borough Council'));
    });

    it('getDriver("invalid") returns null', () => {
      assert.strictEqual(getDriver('invalid'), null);
    });

    it('getDriver(null) returns null', () => {
      assert.strictEqual(getDriver(null), null);
    });

    it('getDriver("") returns null', () => {
      assert.strictEqual(getDriver(''), null);
    });
  });

  describe('Derby driver', () => {
    const derby = require('../lib/drivers/derby');

    it('has correct id, slug, name', () => {
      assert.strictEqual(derby.id, 'derby');
      assert.strictEqual(derby.slug, 'derby');
      assert.strictEqual(derby.name, 'Derby City Council');
    });

    it('has lookupAddresses method', () => {
      assert.strictEqual(typeof derby.lookupAddresses, 'function');
    });

    it('has getCollections method', () => {
      assert.strictEqual(typeof derby.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await derby.getCollections(null);
      assert.deepStrictEqual(result, []);
    });

    it('getCollections("") returns []', async () => {
      const result = await derby.getCollections('');
      assert.deepStrictEqual(result, []);
    });

    it('lookupAddresses("") returns []', async () => {
      const result = await derby.lookupAddresses('');
      assert.deepStrictEqual(result, []);
    });
  });

  describe('Erewash driver', () => {
    const erewash = require('../lib/drivers/erewash');

    it('has correct id, slug, name', () => {
      assert.strictEqual(erewash.id, 'erewash');
      assert.strictEqual(erewash.slug, 'erewash');
      assert.strictEqual(erewash.name, 'Erewash Borough Council');
    });

    it('has lookupAddresses method', () => {
      assert.strictEqual(typeof erewash.lookupAddresses, 'function');
    });

    it('has getCollections method', () => {
      assert.strictEqual(typeof erewash.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await erewash.getCollections(null);
      assert.deepStrictEqual(result, []);
    });

    it('getCollections("") returns []', async () => {
      const result = await erewash.getCollections('');
      assert.deepStrictEqual(result, []);
    });

    it('getCollections without postcode returns []', async () => {
      const result = await erewash.getCollections('100023456789');
      assert.deepStrictEqual(result, []);
    });

    it('lookupAddresses("") returns []', async () => {
      const result = await erewash.lookupAddresses('');
      assert.deepStrictEqual(result, []);
    });

    it('lookupAddresses(null) returns []', async () => {
      const result = await erewash.lookupAddresses(null);
      assert.deepStrictEqual(result, []);
    });

    it('lookupAddresses("   ") returns []', async () => {
      const result = await erewash.lookupAddresses('   ');
      assert.deepStrictEqual(result, []);
    });
  });

  describe('Amber Valley driver', () => {
    const av = require('../lib/drivers/ambervalley');

    it('has correct id, slug, name', () => {
      assert.strictEqual(av.id, 'ambervalley');
      assert.strictEqual(av.slug, 'ambervalley');
      assert.strictEqual(av.name, 'Amber Valley Borough Council');
    });

    it('has lookupAddresses and getCollections methods', () => {
      assert.strictEqual(typeof av.lookupAddresses, 'function');
      assert.strictEqual(typeof av.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await av.getCollections(null);
      assert.deepStrictEqual(result, []);
    });
  });

  describe('High Peak driver', () => {
    const hp = require('../lib/drivers/highpeak');

    it('has correct id, slug, name', () => {
      assert.strictEqual(hp.id, 'highpeak');
      assert.strictEqual(hp.slug, 'highpeak');
      assert.strictEqual(hp.name, 'High Peak Borough Council');
    });

    it('has lookupAddresses and getCollections methods', () => {
      assert.strictEqual(typeof hp.lookupAddresses, 'function');
      assert.strictEqual(typeof hp.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await hp.getCollections(null);
      assert.deepStrictEqual(result, []);
    });
  });

  describe('Derbyshire Dales driver', () => {
    const dd = require('../lib/drivers/derbyshiredales');

    it('has correct id, slug, name', () => {
      assert.strictEqual(dd.id, 'derbyshiredales');
      assert.strictEqual(dd.slug, 'derbyshiredales');
      assert.strictEqual(dd.name, 'Derbyshire Dales District Council');
    });

    it('has lookupAddresses and getCollections methods', () => {
      assert.strictEqual(typeof dd.lookupAddresses, 'function');
      assert.strictEqual(typeof dd.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await dd.getCollections(null);
      assert.deepStrictEqual(result, []);
    });
  });

  describe('Bolsover driver', () => {
    const bol = require('../lib/drivers/bolsover');

    it('has correct id, slug, name', () => {
      assert.strictEqual(bol.id, 'bolsover');
      assert.strictEqual(bol.slug, 'bolsover');
      assert.strictEqual(bol.name, 'Bolsover District Council');
    });

    it('has lookupAddresses and getCollections methods', () => {
      assert.strictEqual(typeof bol.lookupAddresses, 'function');
      assert.strictEqual(typeof bol.getCollections, 'function');
    });
  });

  describe('Chesterfield driver', () => {
    const che = require('../lib/drivers/chesterfield');

    it('has correct id, slug, name', () => {
      assert.strictEqual(che.id, 'chesterfield');
      assert.strictEqual(che.slug, 'chesterfield');
      assert.strictEqual(che.name, 'Chesterfield Borough Council');
    });

    it('has lookupAddresses and getCollections methods', () => {
      assert.strictEqual(typeof che.lookupAddresses, 'function');
      assert.strictEqual(typeof che.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await che.getCollections(null);
      assert.deepStrictEqual(result, []);
    });
  });

  describe('South Derbyshire driver', () => {
    const sd = require('../lib/drivers/southderbyshire');

    it('has correct id, slug, name', () => {
      assert.strictEqual(sd.id, 'southderbyshire');
      assert.strictEqual(sd.slug, 'southderbyshire');
      assert.strictEqual(sd.name, 'South Derbyshire District Council');
    });

    it('has lookupAddresses and getCollections methods', () => {
      assert.strictEqual(typeof sd.lookupAddresses, 'function');
      assert.strictEqual(typeof sd.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await sd.getCollections(null);
      assert.deepStrictEqual(result, []);
    });
  });

  describe('North East Derbyshire driver', () => {
    const ned = require('../lib/drivers/northeastderbyshire');

    it('has correct id, slug, name', () => {
      assert.strictEqual(ned.id, 'northeastderbyshire');
      assert.strictEqual(ned.slug, 'northeastderbyshire');
      assert.strictEqual(ned.name, 'North East Derbyshire District Council');
    });

    it('has lookupAddresses and getCollections methods', () => {
      assert.strictEqual(typeof ned.lookupAddresses, 'function');
      assert.strictEqual(typeof ned.getCollections, 'function');
    });

    it('getCollections(null) returns []', async () => {
      const result = await ned.getCollections(null);
      assert.deepStrictEqual(result, []);
    });

    it('getCollections without postcode returns []', async () => {
      const result = await ned.getCollections('12345');
      assert.deepStrictEqual(result, []);
    });

    it('lookupAddresses("") returns []', async () => {
      const result = await ned.lookupAddresses('');
      assert.deepStrictEqual(result, []);
    });

    it('lookupAddresses(null) returns []', async () => {
      const result = await ned.lookupAddresses(null);
      assert.deepStrictEqual(result, []);
    });

    it('lookupAddresses("   ") returns []', async () => {
      const result = await ned.lookupAddresses('   ');
      assert.deepStrictEqual(result, []);
    });
  });

  {
    console.log('\n  Bins API endpoint');

    const handler = require('../api/bins');
    const drivers = require('../lib/drivers');
    const origGet = drivers.getDriver;

    function mockRes() {
      const r = { _status: 200, _headers: {}, _body: null };
      r.setHeader = (k, v) => { r._headers[k] = v; };
      r.status = (s) => { r._status = s; return r; };
      r.json = (d) => { r._body = d; return r; };
      r.end = () => r;
      return r;
    }

    await itAsync('no params: req.query={} returns 200 with councils array', async () => {
      const req = { method: 'GET', query: {} };
      const res = mockRes();
      await handler(req, res);
      assert.strictEqual(res._status, 200);
      assert.ok(Array.isArray(res._body.councils), 'councils should be an array');
    });

    await itAsync('unknown council: req.query={council:"xyz"} returns 404', async () => {
      const req = { method: 'GET', query: { council: 'xyz' } };
      const res = mockRes();
      await handler(req, res);
      assert.strictEqual(res._status, 404);
    });

    await itAsync('missing uprn/postcode: req.query={council:"derby"} returns 400', async () => {
      const req = { method: 'GET', query: { council: 'derby' } };
      const res = mockRes();
      await handler(req, res);
      assert.strictEqual(res._status, 400);
    });

    await itAsync('postcode query with mock driver returns addresses', async () => {
      drivers.getDriver = () => ({
        id: 'derby',
        name: 'Derby City Council',
        lookupAddresses: async () => [{ uprn: '123', label: '1 Test St' }],
        getCollections: async () => [{ stream: 'general', frequency: 'weekly' }],
      });

      const req = { method: 'GET', query: { council: 'derby', postcode: 'DE1 1RT' } };
      const res = mockRes();
      await handler(req, res);
      assert.strictEqual(res._status, 200);
      assert.ok(Array.isArray(res._body.addresses), 'addresses should be an array');
      assert.strictEqual(res._body.addresses.length, 1);
      assert.strictEqual(res._body.addresses[0].uprn, '123');

      drivers.getDriver = origGet;
    });

    await itAsync('uprn query with mock driver returns collections', async () => {
      drivers.getDriver = () => ({
        id: 'derby',
        name: 'Derby City Council',
        lookupAddresses: async () => [{ uprn: '123', label: '1 Test St' }],
        getCollections: async () => [{ stream: 'general', frequency: 'weekly' }],
      });

      const req = { method: 'GET', query: { council: 'derby', uprn: '123' } };
      const res = mockRes();
      await handler(req, res);
      assert.strictEqual(res._status, 200);
      assert.ok(Array.isArray(res._body.collections), 'collections should be an array');
      assert.strictEqual(res._body.collections.length, 1);
      assert.strictEqual(res._body.collections[0].stream, 'general');

      drivers.getDriver = origGet;
    });
  }

  describe('Shared utilities', () => {
    const { httpGet, httpPost, cookieJarFrom, cookieHeader, encodeForm } = require('../lib/drivers/shared');

    it('httpGet is a function', () => {
      assert.strictEqual(typeof httpGet, 'function');
    });

    it('httpGet returns a promise', () => {
      const p = httpGet('https://example.com');
      assert.ok(p instanceof Promise, 'httpGet should return a Promise');
      p.catch(() => {});
    });

    it('httpPost is a function', () => {
      assert.strictEqual(typeof httpPost, 'function');
    });

    it('cookieJarFrom is a function', () => {
      assert.strictEqual(typeof cookieJarFrom, 'function');
    });

    it('cookieHeader is a function', () => {
      assert.strictEqual(typeof cookieHeader, 'function');
    });

    it('encodeForm is a function', () => {
      assert.strictEqual(typeof encodeForm, 'function');
    });

    it('encodeForm encodes key-value pairs', () => {
      const result = encodeForm({ foo: 'bar', baz: '123' });
      assert.strictEqual(result, 'foo=bar&baz=123');
    });

    it('cookieJarFrom parses set-cookie header', () => {
      const jar = cookieJarFrom({ 'set-cookie': ['token=abc123; Path=/', 'other=xyz; Path=/'] });
      assert.strictEqual(jar.token, 'abc123');
      assert.strictEqual(jar.other, 'xyz');
    });

    it('cookieHeader builds cookie string', () => {
      const header = cookieHeader({ token: 'abc', other: 'xyz' });
      assert.ok(header.includes('token=abc'));
      assert.ok(header.includes('other=xyz'));
    });
  });

  {
    console.log('\n  Report API endpoint');

    const reportHandler = require('../api/report');
    const origEnv = process.env.REPORT_SCRIPT_URL;

    function mockReq(method, body) {
      const r = { method, on: (evt, cb) => { if (evt === 'data') cb(body ? JSON.stringify(body) : ''); if (evt === 'end') cb(); } };
      return r;
    }

    function mockRes() {
      const r = { _status: 200, _headers: {}, _body: null };
      r.setHeader = (k, v) => { r._headers[k] = v; };
      r.status = (s) => { r._status = s; return r; };
      r.json = (d) => { r._body = d; return r; };
      r.end = () => r;
      return r;
    }

    await itAsync('OPTIONS returns 204', async () => {
      const req = { method: 'OPTIONS' };
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 204);
    });

    await itAsync('GET returns 405', async () => {
      const req = { method: 'GET' };
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 405);
      assert.strictEqual(res._body.error, 'method_not_allowed');
    });

    await itAsync('POST with bad JSON returns 400', async () => {
      const req = { method: 'POST', on: (evt, cb) => { if (evt === 'data') cb('not json'); if (evt === 'end') cb(); } };
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 400);
      assert.strictEqual(res._body.error, 'bad_json');
    });

    await itAsync('POST missing name returns 400', async () => {
      const req = mockReq('POST', { email: 'test@test.com' });
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 400);
      assert.strictEqual(res._body.field, 'name');
    });

    await itAsync('POST missing email returns 400', async () => {
      const req = mockReq('POST', { name: 'Test' });
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 400);
      assert.strictEqual(res._body.field, 'email');
    });

    await itAsync('POST invalid email returns 400', async () => {
      const req = mockReq('POST', { name: 'Test', email: 'bad' });
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 400);
      assert.strictEqual(res._body.field, 'email');
    });

    await itAsync('POST honeypot filled returns 200 silently', async () => {
      const req = mockReq('POST', { name: 'Bot', email: 'bot@bot.com', hp: 'spam' });
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 200);
    });

    await itAsync('POST without REPORT_SCRIPT_URL returns 503', async () => {
      delete process.env.REPORT_SCRIPT_URL;
      const req = mockReq('POST', { name: 'Test', email: 'test@test.com' });
      const res = mockRes();
      await reportHandler(req, res);
      assert.strictEqual(res._status, 503);
      if (origEnv) process.env.REPORT_SCRIPT_URL = origEnv;
    });
  }

  console.log(`\n  ${passes} passed, ${failures} failed\n`);
  process.exit(failures > 0 ? 1 : 0);
}

run();
