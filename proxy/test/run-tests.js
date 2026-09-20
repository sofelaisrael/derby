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

    it('listDrivers returns array with length >= 2', () => {
      assert.ok(Array.isArray(drivers), 'should be an array');
      assert.ok(drivers.length >= 2, `expected >= 2, got ${drivers.length}`);
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

    it('lookupAddresses("") returns []', async () => {
      const result = await erewash.lookupAddresses('');
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
    const { httpGet } = require('../lib/drivers/shared');

    it('httpGet is a function', () => {
      assert.strictEqual(typeof httpGet, 'function');
    });

    it('httpGet returns a promise', () => {
      const p = httpGet('https://example.com');
      assert.ok(p instanceof Promise, 'httpGet should return a Promise');
      p.catch(() => {});
    });
  });

  console.log(`\n  ${passes} passed, ${failures} failed\n`);
  process.exit(failures > 0 ? 1 : 0);
}

run();
