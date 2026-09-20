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

    res.setHeader('Content-Type', 'application/json');
    return res.status(400).json({ error: 'Provide council + postcode or council + uprn' });
  } catch (e) {
    res.setHeader('Content-Type', 'application/json');
    const status = e.code === 'UPSTREAM_ERROR' ? 502 : e.code === 'PARSE_ERROR' ? 502 : 500;
    return res.status(status).json({ error: e.message, code: e.code || 'UNKNOWN' });
  }
};
