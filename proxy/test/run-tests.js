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

async function describeAsync(name, fn) { console.log(`\n  ${name}`); await fn(); }

async function run() {
  describe('Driver Registry', () => {
    const { listDrivers, getDriver } = require('../lib/drivers');

    const drivers = listDrivers();

    it('listDrivers returns array with length >= 9', () => {
      assert.ok(Array.isArray(drivers), 'should be an array');
      assert.ok(drivers.length >= 9, `expected >= 9, got ${drivers.length}`);
    });

    it('each item has id, name, slug, calendarBased properties', () => {
      for (const d of drivers) {
        assert.ok(d.id, `missing id on ${JSON.stringify(d)}`);
        assert.ok(d.name, `missing name on ${JSON.stringify(d)}`);
        assert.ok(d.slug, `missing slug on ${JSON.stringify(d)}`);
        assert.strictEqual(typeof d.calendarBased, 'boolean', `missing calendarBased on ${JSON.stringify(d)}`);
      }
    });

    it('bolsover and northeastderbyshire are calendar-based, others are not', () => {
      const bol = drivers.find(d => d.slug === 'bolsover');
      const ned = drivers.find(d => d.slug === 'northeastderbyshire');
      const derby = drivers.find(d => d.slug === 'derby');
      assert.strictEqual(bol.calendarBased, true);
      assert.strictEqual(ned.calendarBased, true);
      assert.strictEqual(derby.calendarBased, false);
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

  await describeAsync('Erewash driver', async () => {
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

    await itAsync('getCollections(null) returns []', async () => {
      const result = await erewash.getCollections(null);
      assert.deepStrictEqual(result, []);
    });

    await itAsync('getCollections("") returns []', async () => {
      const result = await erewash.getCollections('');
      assert.deepStrictEqual(result, []);
    });

    await itAsync('getCollections without postcode returns []', async () => {
      const result = await erewash.getCollections('100023456789');
      assert.deepStrictEqual(result, []);
    });

    await itAsync('getCollections with a non-numeric uprn returns [] without calling the site', async () => {
      const result = await erewash.getCollections('not-a-uprn', 'DE7 4AA');
      assert.deepStrictEqual(result, []);
    });

    await itAsync('lookupAddresses("") returns []', async () => {
      const result = await erewash.lookupAddresses('');
      assert.deepStrictEqual(result, []);
    });

    await itAsync('lookupAddresses(null) returns []', async () => {
      const result = await erewash.lookupAddresses(null);
      assert.deepStrictEqual(result, []);
    });

    await itAsync('lookupAddresses("   ") returns []', async () => {
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

    it('lookupAddresses("") returns the two calendar options', async () => {
      const result = await bol.lookupAddresses('');
      assert.strictEqual(result.length, 2);
      assert.strictEqual(result[0].uprn, 'calendar-a');
      assert.strictEqual(result[1].uprn, 'calendar-b');
    });

    it('lookupAddresses(null) returns the two calendar options', async () => {
      const result = await bol.lookupAddresses(null);
      assert.strictEqual(result.length, 2);
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

    it('lookupAddresses("") returns the two calendar options', async () => {
      const result = await ned.lookupAddresses('');
      assert.strictEqual(result.length, 2);
      assert.strictEqual(result[0].uprn, 'calendar-a');
      assert.ok(result[0].label.startsWith('Calendar A - The North:'), `expected north label prefix, got: ${result[0].label}`);
      assert.ok(result[0].label.includes('Dronfield'), `expected north label to include Dronfield, got: ${result[0].label}`);
      assert.strictEqual(result[1].uprn, 'calendar-b');
      assert.ok(result[1].label.startsWith('Calendar B - The South:'), `expected south label prefix, got: ${result[1].label}`);
      assert.ok(result[1].label.includes('Clay Cross'), `expected south label to include Clay Cross, got: ${result[1].label}`);
    });

    it('lookupAddresses(null) returns the two calendar options', async () => {
      const result = await ned.lookupAddresses(null);
      assert.strictEqual(result.length, 2);
    });

    it('lookupAddresses("   ") returns the two calendar options', async () => {
      const result = await ned.lookupAddresses('   ');
      assert.strictEqual(result.length, 2);
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

    await itAsync('calendar-based council without postcode returns calendar options', async () => {
      drivers.getDriver = () => ({
        id: 'bolsover',
        name: 'Bolsover District Council',
        calendarBased: true,
        lookupAddresses: async () => [
          { uprn: 'calendar-a', label: 'Calendar A' },
          { uprn: 'calendar-b', label: 'Calendar B' },
        ],
        getCollections: async () => [],
      });

      const req = { method: 'GET', query: { council: 'bolsover' } };
      const res = mockRes();
      await handler(req, res);
      assert.strictEqual(res._status, 200);
      assert.ok(Array.isArray(res._body.addresses), 'addresses should be an array');
      assert.strictEqual(res._body.addresses.length, 2);
      assert.strictEqual(res._body.addresses[0].uprn, 'calendar-a');

      drivers.getDriver = origGet;
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

  // ───────────────────────────────────────────────────────────────────────────
  // Driver regression fixtures.
  //
  // Before this block the suite asserted a two-field stub from a mocked driver
  // and never executed a parser, which is why the stream-parsing bugs shipped.
  // Every case below drives a real driver's pure export with a fixed `now`, so
  // nothing reads the clock.
  //
  // Each envelope's `source.regression` states what the bug was. These cannot be
  // run RED against the pre-fix drivers: the `_`-prefixed pure exports they call
  // did not exist then, so reverting the drivers yields "TypeError: not a
  // function" rather than a real assertion failure. The expectations encode the
  // correct post-fix behaviour; the regressions are recorded, not demonstrated.
  //
  // All bodies are synthetic minimal inputs, not council recordings. See
  // test/fixtures/index.js for why, and for the URLs to replace them with.
  // ───────────────────────────────────────────────────────────────────────────
  await describeAsync('Council fixtures', async () => {
    const { SLUGS, CASES, runFixture } = require('./fixtures');
    const { listDrivers } = require('../lib/drivers');

    it('every covered slug is a real driver', () => {
      const known = new Set(listDrivers().map((d) => d.slug));
      for (const slug of SLUGS) {
        assert.ok(known.has(slug), `${slug} has fixtures but is not a registered driver`);
      }
    });

    it('every covered slug has at least one fixture', () => {
      for (const slug of SLUGS) {
        const cases = CASES.filter((c) => c.slug === slug);
        assert.ok(cases.length > 0, `${slug} has no fixtures`);
      }
    });

    it('fixture case names are unique per slug', () => {
      const seen = new Set();
      for (const c of CASES) {
        const key = `${c.slug}/${c.case}`;
        assert.ok(!seen.has(key), `duplicate fixture ${key}`);
        seen.add(key);
      }
    });

    it('every fixture is labelled as a synthetic input', () => {
      for (const c of CASES) {
        assert.strictEqual(c.source && c.source.kind, 'synthetic',
          `${c.slug}/${c.case} must declare source.kind`);
        assert.ok(c.source.note && c.source.note.length > 0,
          `${c.slug}/${c.case} must carry a source.note`);
      }
    });

    it('every collection group carries exactly the four wire fields', () => {
      const required = ['stream', 'dayOfWeek', 'frequency', 'anchorDate'];
      for (const c of CASES) {
        for (const group of runFixture(c)) {
          for (const field of required) {
            assert.ok(field in group, `${c.slug}/${c.case}: group missing ${field}`);
          }
          assert.ok(!('colour' in group),
            `${c.slug}/${c.case}: wire contract must not gain a colour field`);
        }
      }
    });

    for (const envelope of CASES) {
      await itAsync(`${envelope.slug}/${envelope.case}`, async () => {
        const collections = runFixture(envelope);
        const byName = new Map(collections.map((g) => [g.stream, g]));
        const want = envelope.expect;

        assert.deepStrictEqual(collections.map((g) => g.stream), want.streams,
          `streams differ (expected ${JSON.stringify(want.streams)})`);

        for (const [stream, expected] of Object.entries(want.byStream || {})) {
          const group = byName.get(stream);
          assert.ok(group, `missing group ${stream}`);
          assert.strictEqual(group.dayOfWeek, expected.dayOfWeek, `${stream} dayOfWeek`);
          assert.strictEqual(group.frequency, expected.frequency, `${stream} frequency`);
          assert.strictEqual(group.anchorDate, expected.anchorDate, `${stream} anchorDate`);
          assert.ok(Array.isArray(group.nextCollections) && group.nextCollections.length > 0,
            `${stream} has no nextCollections`);
        }

        for (const [stream, label] of Object.entries(want.labels || {})) {
          const group = byName.get(stream);
          assert.ok(group, `missing group ${stream}`);
          assert.strictEqual(group.nextCollections[0].label, label, `${stream} label`);
        }
      });
    }
  });

  // ───────────────────────────────────────────────────────────────────────────
  // The fixed stream-parsing bugs, asserted directly against the pure mappers so
  // a failure points at the classification rather than at a parsed fixture.
  //
  // NOTE ON RED-BEFORE: the four bugs below are real and were confirmed from the
  // driver diff, but this suite cannot demonstrate RED against the pre-fix
  // drivers. Every case here (and in test/fixtures/) calls a `_`-prefixed pure
  // export that does not exist on the original drivers, so reverting the driver
  // changes yields "TypeError: not a function" rather than a meaningful
  // assertion failure. Each test therefore states the OLD and NEW expectation in
  // its name or comment so the regression intent is legible without a red run.
  // ───────────────────────────────────────────────────────────────────────────
  describe('Stream classification', () => {
    const av = require('../lib/drivers/ambervalley');
    const ned = require('../lib/drivers/northeastderbyshire');
    const bol = require('../lib/drivers/bolsover');
    const ddd = require('../lib/drivers/derbyshiredales');
    const derby = require('../lib/drivers/derby');

    // ── AVBC ────────────────────────────────────────────────────────────────
    // The AVBC food field name is not publicly documented.
    it('ambervalley resolves foodNextDate', () => {
      assert.strictEqual(av._resolveDateKey({ foodNextDate: '2026-10-07' },
        { keys: ['foodNextDate'], sweep: true }), 'foodNextDate');
    });

    it('ambervalley resolves nextFoodDate', () => {
      assert.strictEqual(av._resolveDateKey({ nextFoodDate: '2026-10-07' },
        { keys: ['foodNextDate', 'nextFoodDate'], sweep: true }), 'nextFoodDate');
    });

    it('ambervalley sweeps an undocumented food spelling', () => {
      assert.strictEqual(av._resolveDateKey({ wibbleFoodNextDate: '2026-10-07' },
        { keys: ['foodNextDate', 'nextFoodDate'], sweep: true }), 'wibbleFoodNextDate');
    });

    it('ambervalley does not sweep a communal or frequency flag', () => {
      const entry = { keys: ['foodNextDate'], sweep: true };
      assert.strictEqual(
        av._resolveDateKey({ communalFoodNextDate: '2026-10-07' }, entry), null);
      assert.strictEqual(
        av._resolveDateKey({ foodWeekly: 'true' }, entry), null);
    });

    it('ambervalley does not sweep a non-date value', () => {
      assert.strictEqual(
        av._resolveDateKey({ foodNextDateCount: 3 },
          { keys: [], sweep: true }), null);
    });

    // FIX 5. OLD: the sweep returned 'foodCollectionNextDate' for the
    // ambiguous string below, and `new Date('12/03/2026')` is 3 December --
    // passing isNaN and getFullYear() < 2000, so a wrong food collection
    // shipped. NEW: rejected for not being ISO-shaped.
    it('ambervalley sweep rejects a non-ISO ambiguous date string (old: accepted as 3 December)', () => {
      const entry = { keys: ['foodNextDate', 'nextFoodDate'], sweep: true };
      assert.strictEqual(
        av._resolveDateKey({ foodCollectionNextDate: '12/03/2026' }, entry), null);
      // Same key, ISO value: still swept.
      assert.strictEqual(
        av._resolveDateKey({ foodCollectionNextDate: '2026-12-03T00:00:00' }, entry),
        'foodCollectionNextDate');
      // The .NET default sentinel is ISO-shaped, so it is still caught by the
      // year >= 2000 guard in buildCollectionsFromFeed rather than the sweep.
      assert.strictEqual(
        av._resolveDateKey({ foodCollectionNextDate: '0001-01-01T00:00:00' }, entry),
        'foodCollectionNextDate');
    });

    it('ambervalley returns null for a stream with no date field', () => {
      assert.strictEqual(av._resolveDateKey({}, { keys: ['refuseNextDate'] }), null);
    });

    // ── NED ─────────────────────────────────────────────────────────────────
    // NED's garden bin is green.
    it('ned maps "Green bin" to garden', () => {
      assert.deepStrictEqual(ned._mapBinTypes('Green bin'), ['garden']);
    });

    it('ned maps "Burgundy recycling" to recycling once', () => {
      assert.deepStrictEqual(ned._mapBinTypes('Burgundy recycling'), ['recycling']);
    });

    it('ned maps "Black bin" to general', () => {
      assert.deepStrictEqual(ned._mapBinTypes('Black bin'), ['general']);
    });

    it('ned maps "Brown food caddy" to food', () => {
      assert.deepStrictEqual(ned._mapBinTypes('Brown food caddy'), ['food']);
    });

    it('ned maps an explicit garden word to garden even when green', () => {
      assert.deepStrictEqual(ned._mapBinTypes('Green garden bin'), ['garden']);
    });

    // FIX 1. OLD: 'Black bin and food caddy' returned ['food'] -- the food
    // match filled `streams`, so the gated black rule was skipped and the
    // refuse collection was lost. The pre-per-council code returned
    // ['general','food']. NEW: black is unambiguous for NED (refuse Black,
    // recycling Burgundy, garden Green, food Brown) so it is not gated, and
    // the unambiguous colours are pushed ABOVE the stream-word block so the
    // pre-fix order is restored.
    it('ned keeps refuse when black is paired with food (old: dropped refuse)', () => {
      assert.deepStrictEqual(
        ned._mapBinTypes('Monday 5th October - Black bin and food caddy'),
        ['general', 'food']);
      assert.deepStrictEqual(
        ned._mapBinTypes('Black bin and garden'), ['general', 'garden']);
      assert.deepStrictEqual(
        ned._mapBinTypes('Black and Burgundy bins'), ['general', 'recycling']);
    });

    // FIX C. Green is unambiguous for NED and is never recycling, so it must not
    // be gated on `streams.length === 0`. OLD: 'Green bin and food caddy'
    // returned ['food'] -- the garden collection was silently lost, and
    // under-detecting garden costs a user a real collection.
    it('ned keeps garden when green is paired with another stream (old: dropped garden)', () => {
      assert.deepStrictEqual(
        ned._mapBinTypes('Green bin and food caddy'), ['garden', 'food']);
      assert.deepStrictEqual(
        ned._mapBinTypes('Green bin'), ['garden']);
      assert.deepStrictEqual(
        ned._mapBinTypes('Green garden bin'), ['garden']);
      assert.deepStrictEqual(
        ned._mapBinTypes('Green waste'), ['garden']);
      assert.deepStrictEqual(
        ned._mapBinTypes('Grass cuttings bin'), ['garden']);
      // Green still never resolves to recycling.
      assert.ok(!ned._mapBinTypes('Green bin').includes('recycling'));
      assert.ok(!ned._mapBinTypes('Green bin and food caddy').includes('recycling'));
    });

    // FIX C, negation. The two-word guard /no (collection|recycling)/ did not
    // match the container-qualified 'No green bin collection', so the line
    // produced a phantom ['garden'] collection. This was ALREADY the behaviour
    // before the green gate was removed, so the phantom is pre-existing rather
    // than introduced here -- which is exactly why it is pinned rather than
    // assumed away. NO_COLLECTION_RE now allows intervening adjectives.
    it('ned returns [] for a negated container-qualified line (old: phantom garden)', () => {
      assert.deepStrictEqual(ned._mapBinTypes('No green bin collection'), []);
      assert.deepStrictEqual(
        ned._mapBinTypes('Monday 5th October - No green bin collection'), []);
      assert.deepStrictEqual(ned._mapBinTypes('No black bin collection'), []);
      assert.deepStrictEqual(ned._mapBinTypes('No burgundy recycling'), []);
      // The two original guard cases still hold.
      assert.deepStrictEqual(ned._mapBinTypes('No collection this week'), []);
      assert.deepStrictEqual(ned._mapBinTypes('No recycling'), []);
    });

    it('ned parseSectionHtml drops a negated container-qualified line', () => {
      const html = [
        '<p>Monday 5th October - No green bin collection</p>',
        '<p>Tuesday 6th October - Black bin</p>',
      ].join('\n');
      const entries = ned._parseSectionHtml(html);
      assert.strictEqual(entries.length, 1, 'only the real collection survives');
      assert.deepStrictEqual(entries[0].streams, ['general']);
    });

    // RESIDUAL, deliberately left visible rather than silently fixed: a
    // line-scoped food negation ("Green bin - no food") still yields
    // ['garden','food'], because a blanket /no ... food/ guard would return []
    // and lose the garden collection too. Bolsover's driver has the scoped
    // narrowing; NED's does not. Fixing it needs a scoped negation, which is a
    // separate change from this one. Pinned so it cannot be mistaken for
    // working behaviour.
    //
    // NOT A REAL-WORLD RISK -- do not "fix" this into a regression. NED's live
    // page writes collections as whole-week noun lists plus a whole-week
    // negation, e.g.:
    //   "Monday 3rd to Friday 7th August: Black Bin and Food Caddy collections."
    //   "Monday 10th to Friday 14th August: Burgundy, Green Bin and Food Caddy collections."
    //   "Monday 31st August: Bank Holiday, No collections"
    // The ONLY negation form NED publishes is the whole-week "No collections",
    // which NO_COLLECTION_RE in lib/drivers/northeastderbyshire.js already
    // handles. NED never writes per-bin negations ("no green bin", "no food"),
    // so this residual is unreachable with real data. The test stays to
    // document the parser's limit, not because a user can currently hit it.
    it('ned does not yet scope a food negation (known residual)', () => {
      assert.deepStrictEqual(
        ned._mapBinTypes('Green bin - no food'), ['garden', 'food']);
    });

    // FIX 6. OLD: the guard was `includes('no collection')` only, so
    // "No recycling" fell through to the `\brecycl` word match and produced a
    // collection that does not exist. The pre-per-council code returned [].
    it('ned returns [] for "no collection"', () => {
      assert.deepStrictEqual(ned._mapBinTypes('No collection this week'), []);
    });

    it('ned returns [] for "no recycling" (old: returned [\'recycling\'])', () => {
      assert.deepStrictEqual(
        ned._mapBinTypes('Thursday 5th March - No recycling'), []);
      assert.deepStrictEqual(ned._mapBinTypes('No recycling'), []);
    });

    // FIX 6, mirrored at parseSectionHtml:124 -- the section-level skip had the
    // same one-sided check, so the entry reached mapBinTypes at all.
    it('ned parseSectionHtml drops both "no collection" and "no recycling" lines', () => {
      const html = [
        '<p>Monday 5th October - No collection</p>',
        '<p>Thursday 5th March - No recycling</p>',
        '<p>Friday 9th October - Black bin</p>',
      ].join('\n');
      const entries = ned._parseSectionHtml(html);
      assert.strictEqual(entries.length, 1, 'only the real collection survives');
      assert.deepStrictEqual(entries[0].streams, ['general']);
    });

    // ── Bolsover ────────────────────────────────────────────────────────────
    // Bolsover's brown 23L food caddy.
    it('bolsover maps "Brown" to food', () => {
      assert.strictEqual(bol._mapBinType('Brown'), 'food');
    });

    it('bolsover maps black/burgundy/green to general/recycling/garden', () => {
      assert.strictEqual(bol._mapBinType('Black'), 'general');
      assert.strictEqual(bol._mapBinType('Burgundy'), 'recycling');
      assert.strictEqual(bol._mapBinType('Green'), 'garden');
    });

    it('bolsover lets an explicit food label beat a green colour match', () => {
      assert.strictEqual(bol._mapBinType('Green food caddy'), 'food');
    });

    // FIX 7. OLD: `t.includes('food')` ran first and unscoped, so
    // "Green bin - no food" routed to food and lost the garden collection.
    // NEW: garden is checked first and food needs a container noun.
    it('bolsover maps "Green bin - no food" to garden (old: routed to food)', () => {
      assert.strictEqual(bol._mapBinType('Green bin - no food'), 'garden');
      assert.strictEqual(bol._mapBinType('Garden bin'), 'garden');
      // The narrowing still accepts the real food spellings.
      assert.strictEqual(bol._mapBinType('Food caddy'), 'food');
      assert.strictEqual(bol._mapBinType('Food waste'), 'food');
      assert.strictEqual(bol._mapBinType('Food bin'), 'food');
      assert.strictEqual(bol._mapBinType('Brown'), 'food');
    });

    it('bolsover returns null for an unknown token', () => {
      assert.strictEqual(bol._mapBinType('Wheelie'), null);
      assert.strictEqual(bol._mapBinType(''), null);
      assert.strictEqual(bol._mapBinType(null), null);
    });

    // ── Derbyshire Dales ────────────────────────────────────────────────────
    // A cell naming two streams.
    const dddRow = (date, type) =>
      '<div class="row" style="padding-left:15px">' +
      `<div class="col-sm-5">${date}</div>` +
      `<div class="col-sm-6">${type}</div>` +
      '</div>';

    it('derbyshire dales maps "Recycling and Garden" to both streams', () => {
      const rows = ddd._parseRows(dddRow('Monday 5 October, 2026', 'Recycling and Garden'));
      assert.deepStrictEqual(rows.map((r) => r.stream), ['recycling', 'garden']);
    });

    // FIX 3. OLD: the row regex's lazy `([\s\S]*?)</div>` ran past the end of
    // row 1 looking for its lookahead terminator, so it parsed N rows as N-1
    // collections and a single-row payload as none at all. NEW: parseRows
    // splits on the row opener, so one row is enough.
    it('derbyshire dales parses a SINGLE row (old: parsed nothing)', () => {
      const rows = ddd._parseRows(dddRow('Monday 5 October, 2026', 'Domestic Waste'));
      assert.strictEqual(rows.length, 1);
      assert.deepStrictEqual(rows.map((r) => r.stream), ['general']);
      assert.strictEqual(ddd._parseRows(dddRow('Monday 5 October, 2026', 'Recycling')).length, 1);
    });

    // FIX 3, multi-row: every row must be read, not every row but the last.
    it('derbyshire dales parses ALL N rows (old: N-1, dropping the last)', () => {
      for (const n of [1, 2, 3, 4, 5]) {
        const html = Array.from({ length: n }, (_, i) =>
          dddRow(`Monday ${5 + i} October, 2026`, 'Domestic Waste')).join('\n');
        assert.strictEqual(ddd._parseRows(html).length, n, `${n} rows`);
      }
    });

    // A single date per stream used to make deriveFrequency's `length < 2`
    // short-circuit report fortnightly for what are weekly collections.
    it('derbyshire dales reports weekly once every row is read (old: fortnightly)', () => {
      const html = [
        dddRow('Monday 5 October, 2026', 'Recycling'),
        dddRow('Monday 12 October, 2026', 'Recycling'),
      ].join('\n');
      const groups = ddd._buildCollectionsFromPage(html, new Date('2026-10-01T00:00:00'), null);
      assert.strictEqual(groups.length, 1);
      assert.strictEqual(groups[0].frequency, 'weekly');
      assert.strictEqual(groups[0].nextCollections.length, 2);
    });

    it('derbyshire dales drops a cell naming no known stream', () => {
      const rows = ddd._parseRows(dddRow('Monday 5 October, 2026', 'Bulky Waste'));
      assert.deepStrictEqual(rows, []);
    });

    // ── Derby ───────────────────────────────────────────────────────────────
    // INVARIANT, not a regression test: the old
    // `Object.fromEntries(...toLowerCase())` already collapsed case, so these
    // two passed before the change too. They pin the single collapsed map.
    it('derby resolves alts case-insensitively', () => {
      const groups = derby._buildCollectionsFromHtml(
        '<div class="binresult"><img alt="Brown Bin"><strong>Wednesday, 7 October 2026</strong></div>' +
        '<div class="binresult"><img alt="Brown Bin"><strong>Wednesday, 14 October 2026</strong></div>');
      assert.deepStrictEqual(groups.map((g) => g.stream), ['garden']);
      assert.strictEqual(groups[0].nextCollections[0].label, 'Garden Waste');
    });

    it('derby resolves every documented alt regardless of case', () => {
      // A key that is not already lowercase could never be reached through
      // `STREAM_BY_ALT[alt.toLowerCase()]`.
      const html = Object.entries({
        'Black Bin': 'general', 'Blue Bin': 'recycling', 'Brown Bin': 'garden',
        'Food Bin': 'food', 'General waste': 'general', 'Recycling': 'recycling',
        'Garden waste': 'garden', 'Food waste': 'food',
      }).map(([alt]) =>
        `<div class="binresult"><img alt="${alt}"><strong>Wednesday, 7 October 2026</strong></div>`).join('');
      const groups = derby._buildCollectionsFromHtml(html);
      assert.deepStrictEqual(groups.map((g) => g.stream).sort(),
        ['food', 'garden', 'general', 'recycling']);
    });

    it('derby still ignores the no-bins placeholder', () => {
      assert.deepStrictEqual(derby._extractCollections(
        '<div class="binresult"><img alt="No bins"><strong>Wednesday, 7 October 2026</strong></div>'), []);
    });
  });

  console.log(`\n  ${passes} passed, ${failures} failed\n`);
  process.exit(failures > 0 ? 1 : 0);
}

run();
