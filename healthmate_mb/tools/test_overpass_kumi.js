const q = `[out:json][timeout:25];
(
  node["amenity"~"hospital"](around:2000,19.076,72.8777);
  way["amenity"~"hospital"](around:2000,19.076,72.8777);
  relation["amenity"~"hospital"](around:2000,19.076,72.8777);
);
out center tags 80;`;
fetch('https://overpass.kumi.systems/api/interpreter', {
  method: 'POST',
  headers: {
    'User-Agent': 'HealthMate/1.0 (local development; healthcare information app)',
    Accept: 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded',
  },
  body: new URLSearchParams({ data: q }).toString(),
  signal: AbortSignal.timeout(30000),
}).then(async (r) => {
  console.log('status', r.status);
  const t = await r.text();
  console.log(t.slice(0, 1000));
}).catch((e) => console.log('ERR', e.name, e.message));
