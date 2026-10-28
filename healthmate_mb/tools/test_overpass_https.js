const https = require('https');
const q = '[out:json][timeout:25];node["amenity"="hospital"](around:1000,19.076,72.8777);out center tags 3;';
const url = new URL('https://overpass-api.de/api/interpreter');
url.searchParams.set('data', q);
const req = https.request(url, {
  method: 'GET',
  family: 4,
  headers: {
    'User-Agent': 'HealthMate/1.0 (local development)',
    Accept: 'application/json',
    Connection: 'close',
  },
  timeout: 45000,
}, (res) => {
  console.log('status', res.statusCode);
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => console.log(data.slice(0, 300)));
});
req.on('timeout', () => { console.log('TIMEOUT'); req.destroy(); });
req.on('error', (e) => console.log('ERR', e.code, e.message));
req.end();
