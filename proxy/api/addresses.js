const drivers = require('../lib/drivers');
const { cacheGet, cacheSet, cacheKey } = require('../lib/shared/cache');

function normalizePostcode(raw) {
  return (raw || '').trim().toUpperCase().replace(/\s+/g, '');
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).end();

  const postcode = normalizePostcode(
    (req.query && req.query.postcode) || ''
  );
  const council = (req.query && req.query.council) || '';

  if (!postcode) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(400).json({ error: 'missing postcode' });
  }

  try {
    const cacheTTL = 24 * 60 * 60 * 1000;

    if (council) {
      const driver = drivers.getDriver(council);
      if (!driver) {
        res.setHeader('Content-Type', 'application/json');
        return res.status(404).json({ error: `Unknown council: ${council}` });
      }
      const ck = cacheKey('addr', council, postcode);
      let addresses = cacheGet(ck);
      if (!addresses) {
        addresses = await driver.lookupAddresses(postcode);
        cacheSet(ck, addresses, cacheTTL);
      }
      res.setHeader('Content-Type', 'application/json');
      return res.status(200).json({ addresses });
    }

    const allList = drivers.listDrivers();
    const merged = [];
    const results = await Promise.allSettled(
      allList.map(d => {
        const driver = drivers.getDriver(d.id);
        const ck = cacheKey('addr', d.id, postcode);
        const cached = cacheGet(ck);
        if (cached) return Promise.resolve(cached);
        return driver.lookupAddresses(postcode).then(addrs => {
          cacheSet(ck, addrs, cacheTTL);
          return addrs;
        });
      })
    );

    for (const r of results) {
      if (r.status === 'fulfilled' && Array.isArray(r.value)) {
        for (const a of r.value) merged.push(a);
      }
    }

    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json({ addresses: merged });
  } catch (e) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(502).json({ error: String((e && e.message) || e) });
  }
};
