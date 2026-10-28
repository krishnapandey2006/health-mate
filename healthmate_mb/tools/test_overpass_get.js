const radiusMeters = 3000;
const latitude = 19.076;
const longitude = 72.8777;
const type = 'hospital';
const amenity = 'hospital';
const q = `[out:json][timeout:25];
(
  node["amenity"~"${amenity}"](around:${radiusMeters},${latitude},${longitude});
  way["amenity"~"${amenity}"](around:${radiusMeters},${latitude},${longitude});
  relation["amenity"~"${amenity}"](around:${radiusMeters},${latitude},${longitude});
);
out center tags 80;`.trim();
const url = new URL('https://overpass-api.de/api/interpreter');
url.searchParams.set('data', q);
console.log('url length', url.toString().length);
fetch(url, {
  headers: {
    'User-Agent': 'HealthMate/1.0 (local development; healthcare information app)',
    Accept: 'application/json',
  },
  signal: AbortSignal.timeout(35000),
}).then(async (r) => {
  console.log('status', r.status);
  const t = await r.text();
  console.log(t.slice(0, 300));
}).catch((e) => console.log('ERR', e.name, e.message));
