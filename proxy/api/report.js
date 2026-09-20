const REQUIRED = ['name', 'email'];

const MAX_BODY = 10240;

const LIMITS = {
  name: 120,
  email: 200,
  description: 2000,
  address: 300,
  council: 120,
  postcode: 12,
  issueType: 60,
};

const ALLOWED_ISSUE_TYPES = [
  'Missing bin',
  'Bin not collected',
  'Bin damaged',
  'Wrong bin collected',
  'Collection schedule wrong',
  'Other',
  'Missing address',
];

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > MAX_BODY) {
        reject(new Error('payload_too_large'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Content-Type', 'application/json');
    return res.status(405).json({ ok: false, error: 'method_not_allowed' });
  }

  let body;
  try {
    body = JSON.parse(await readBody(req));
  } catch (e) {
    res.setHeader('Content-Type', 'application/json');
    if (e && e.message === 'payload_too_large') {
      return res.status(413).json({ ok: false, error: 'payload_too_large' });
    }
    return res.status(400).json({ ok: false, error: 'bad_json' });
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(400).json({ ok: false, error: 'bad_json' });
  }

  if (typeof body.hp === 'string' && body.hp.trim() !== '') {
    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json({ ok: true });
  }

  const cleaned = {};
  for (const key of ['name', 'email', 'issueType', 'description', 'address', 'council', 'postcode']) {
    cleaned[key] = typeof body[key] === 'string' ? body[key].trim() : '';
  }

  for (const key of REQUIRED) {
    if (!cleaned[key]) {
      res.setHeader('Content-Type', 'application/json');
      return res.status(400).json({ ok: false, error: 'missing_field', field: key });
    }
  }

  if (!/^\S+@\S+\.\S+$/.test(cleaned.email)) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(400).json({ ok: false, error: 'invalid_email', field: 'email' });
  }

  for (const [key, max] of Object.entries(LIMITS)) {
    if (cleaned[key].length > max) {
      res.setHeader('Content-Type', 'application/json');
      return res.status(400).json({ ok: false, error: 'field_too_long', field: key });
    }
  }

  if (cleaned.issueType && !ALLOWED_ISSUE_TYPES.includes(cleaned.issueType)) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(400).json({ ok: false, error: 'invalid_issue_type' });
  }

  if (!process.env.REPORT_SCRIPT_URL) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(503).json({ ok: false, error: 'service_unavailable' });
  }

  const payload = {
    name: cleaned.name,
    email: cleaned.email,
  };
  for (const key of ['issueType', 'description', 'address', 'council', 'postcode']) {
    if (cleaned[key]) payload[key] = cleaned[key];
  }

  try {
    const upstream = await fetch(process.env.REPORT_SCRIPT_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(20000),
    });
    console.log({ ok: upstream.ok, status: upstream.status });
    res.setHeader('Content-Type', 'application/json');
    if (upstream.ok) return res.status(200).json({ ok: true });
    return res.status(502).json({ ok: false, error: 'upstream_error' });
  } catch (e) {
    res.setHeader('Content-Type', 'application/json');
    return res.status(502).json({ ok: false, error: 'upstream_unreachable' });
  }
};
