const drivers = require('../lib/drivers');

function normalizePostcode(raw) {
  return (raw || '').trim().toUpperCase().replace(/\s+/g, '');
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).end();

  const { council, postcode, uprn } = req.query || {};

  if (!council && !postcode && !uprn) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json({ councils: drivers.listDrivers() });
  }

  const isAuto = (council || '').toLowerCase() === 'auto' || !council;

  if (!isAuto) {
    const driver = drivers.getDriver(council || '');
    if (!driver) {
      res.setHeader('Content-Type', 'application/json');
      return res.status(404).json({ error: `Unknown council: ${council}`, councils: drivers.listDrivers() });
    }

    try {
      if (uprn) {
        const collections = await driver.getCollections(uprn, postcode || undefined);
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).json({ council: { id: driver.id, name: driver.name }, collections });
      }

      if (postcode) {
        const addresses = await driver.lookupAddresses(postcode);
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).json({ council: { id: driver.id, name: driver.name }, addresses });
      }

      // Calendar-based councils (e.g. Bolsover, North East Derbyshire) don't
      // need a postcode: a council-only request returns the calendar options.
      if (driver.calendarBased) {
        const addresses = await driver.lookupAddresses('');
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).json({ council: { id: driver.id, name: driver.name }, addresses });
      }

      res.setHeader('Content-Type', 'application/json');
      return res.status(400).json({ error: 'Provide council + postcode or council + uprn' });
    } catch (e) {
      res.setHeader('Content-Type', 'application/json');
      const status = e.code === 'UPSTREAM_ERROR' ? 502 : e.code === 'PARSE_ERROR' ? 502 : 500;
      return res.status(status).json({ error: e.message, code: e.code || 'UNKNOWN' });
    }
  }

  if (!uprn) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(400).json({ error: 'Provide uprn for auto-detection' });
  }

  try {
    const allList = drivers.listDrivers();
    const results = await Promise.allSettled(
      allList.map(d => {
        const driver = drivers.getDriver(d.id);
        return driver.getCollections(uprn, postcode || undefined);
      })
    );

    for (let i = 0; i < results.length; i++) {
      const r = results[i];
      if (r.status === 'fulfilled' && Array.isArray(r.value) && r.value.length > 0) {
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).json({
          council: { id: allList[i].id, name: allList[i].name },
          collections: r.value,
        });
      }
    }

    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json({ council: { id: 'auto', name: 'Unknown' }, collections: [] });
  } catch (e) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(500).json({ error: e.message, code: e.code || 'UNKNOWN' });
  }
};
