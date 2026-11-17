async function handle(req, res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Install');
  if (req.method === 'OPTIONS') return res.status(204).send('');
  const path = (req.path || '/').replace(/\/+$/, '') || '/';
  if (path === '/ping') return res.json({ ok: true, at: Date.now() });
  return res.status(404).json({ error: 'not_found' });
}
module.exports = { handle };
