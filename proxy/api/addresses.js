const { lookupAddressesOsPlaces } = require('../lib/drivers/shared');

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
  if (!postcode) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(400).json({ error: 'missing postcode' });
  }

  try {
    const addresses = await lookupAddressesOsPlaces(postcode);
    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json(addresses);
  } catch (e) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(502).json({ error: String((e && e.message) || e) });
  }
};
