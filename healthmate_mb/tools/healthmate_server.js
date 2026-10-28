'use strict';

/**
 * HealthMate API proxy.
 *
 * The Flutter client never receives provider API keys. This small server keeps
 * upstream requests server-side and returns only the data the app needs.
 *
 * Start:  node tools/healthmate_server.js
 * Env:    PORT (default 8787), HOST (default 0.0.0.0),
 *         HEALTHMATE_ALLOWED_ORIGIN (default *),
 *         HEALTHMATE_NEWS_TTL_MS, HEALTHMATE_FACILITY_TTL_MS
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { XMLParser } = require('fast-xml-parser');

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const ALLOWED_ORIGIN = process.env.HEALTHMATE_ALLOWED_ORIGIN || '*';
const NEWS_TTL = Number(process.env.HEALTHMATE_NEWS_TTL_MS || 5 * 60 * 1000);
const FACILITY_TTL = Number(process.env.HEALTHMATE_FACILITY_TTL_MS || 10 * 60 * 1000);
const GEOCODE_TTL = 24 * 60 * 60 * 1000;
const MAX_CACHE_ENTRIES = 400;

const CAMPAIGNS_FILE = path.join(__dirname, '..', 'assets', 'campaigns.json');
const USER_AGENT = 'HealthMate/1.0 (local development; healthcare information app)';
const OVERPASS_ENDPOINT = 'https://overpass-api.de/api/interpreter';
const NOMINATIM_ENDPOINT = 'https://nominatim.openstreetmap.org/search';

const cache = new Map();
const rateBuckets = new Map();
const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  textNodeName: '#text',
  trimValues: true,
});

const CATEGORY_QUERIES = {
  all: 'health India',
  public_health: 'public health India',
  vaccination: 'vaccination India',
  prevention: 'disease prevention India',
  healthcare: 'healthcare India',
  research: 'medical research India',
};

const LOCAL_CATEGORY_QUERIES = {
  hi: {
    all: 'स्वास्थ्य भारत',
    public_health: 'जन स्वास्थ्य भारत',
    vaccination: 'टीकाकरण भारत',
    prevention: 'बीमारी रोकथाम भारत',
    healthcare: 'स्वास्थ्य सेवा भारत',
    research: 'चिकित्सा शोध भारत',
  },
  mr: {
    all: 'आरोग्य भारत',
    public_health: 'सार्वजनिक आरोग्य भारत',
    vaccination: 'लसीकरण भारत',
    prevention: 'आजार प्रतिबंध भारत',
    healthcare: 'आरोग्य सेवा भारत',
    research: 'वैद्यकीय संशोधन भारत',
  },
  bn: {
    all: 'স্বাস্থ্য ভারত',
    public_health: 'জনস্বাস্থ্য ভারত',
    vaccination: 'টিকাকরণ ভারত',
    prevention: 'রোগ প্রতিরোধ ভারত',
    healthcare: 'স্বাস্থ্যসেবা ভারত',
    research: 'চিকিৎসা গবেষণা ভারত',
  },
  gu: {
    all: 'આરોગ્ય ભારત',
    public_health: 'જાહેર આરોગ્ય ભારત',
    vaccination: 'રસીકરણ ભારત',
    prevention: 'રોગ નિવારણ ભારત',
    healthcare: 'આરોગ્ય સેવા ભારત',
    research: 'તબીબી સંશોધન ભારત',
  },
  ta: {
    all: 'சுகாதாரம் இந்தியா',
    public_health: 'பொது சுகாதாரம் இந்தியா',
    vaccination: 'தடுப்பூசி இந்தியா',
    prevention: 'நோய் தடுப்பு இந்தியா',
    healthcare: 'சுகாதார சேவை இந்தியா',
    research: 'மருத்துவ ஆராய்ச்சி இந்தியா',
  },
};

const NEWS_LOCALES = {
  en: { hl: 'en-IN', gl: 'IN', ceid: 'IN:en' },
  hi: { hl: 'hi', gl: 'IN', ceid: 'IN:hi' },
  mr: { hl: 'mr', gl: 'IN', ceid: 'IN:mr' },
  bn: { hl: 'bn', gl: 'IN', ceid: 'IN:bn' },
  gu: { hl: 'gu', gl: 'IN', ceid: 'IN:gu' },
  ta: { hl: 'ta', gl: 'IN', ceid: 'IN:ta' },
};

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept');
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('X-Content-Type-Options', 'nosniff');
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function sendError(res, status, message, type = 'upstream_error') {
  sendJson(res, status, {
    error: { type, message },
    lastUpdated: new Date().toISOString(),
  });
}

function getCache(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expires) {
    cache.delete(key);
    return null;
  }
  return entry.value;
}

function setCache(key, value, ttl) {
  if (cache.size >= MAX_CACHE_ENTRIES) {
    const oldest = cache.keys().next().value;
    if (oldest) cache.delete(oldest);
  }
  cache.set(key, { value, expires: Date.now() + ttl });
}

function allowRequest(req) {
  const forwarded = req.headers['x-forwarded-for'];
  const ip = (Array.isArray(forwarded) ? forwarded[0] : forwarded || req.socket.remoteAddress || 'unknown')
    .split(',')[0]
    .trim();
  const now = Date.now();
  const bucket = rateBuckets.get(ip) || { count: 0, reset: now + 60_000 };
  if (now > bucket.reset) {
    bucket.count = 0;
    bucket.reset = now + 60_000;
  }
  bucket.count += 1;
  rateBuckets.set(ip, bucket);
  return bucket.count <= 120;
}

function cleanText(value, maxLength = 1000) {
  if (value == null) return '';
  let text = String(value);
  text = text
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\s+/g, ' ')
    .trim();
  return text.length > maxLength ? `${text.slice(0, maxLength - 1).trim()}…` : text;
}

function asArray(value) {
  if (value == null) return [];
  return Array.isArray(value) ? value : [value];
}

function nodeText(value) {
  if (value == null) return '';
  if (typeof value === 'string' || typeof value === 'number') return String(value);
  if (Array.isArray(value)) return nodeText(value[0]);
  if (typeof value === 'object') {
    if (value['#text'] != null) return nodeText(value['#text']);
    if (value['@_href'] != null) return nodeText(value['@_href']);
    if (value['@_url'] != null) return nodeText(value['@_url']);
  }
  return '';
}

function safeUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(String(value));
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.toString();
  } catch (_) {
    return null;
  }
}

function parseDate(value) {
  const text = nodeText(value);
  const date = text ? new Date(text) : null;
  return date && !Number.isNaN(date.getTime()) ? date.toISOString() : new Date().toISOString();
}

function extractImage(item) {
  const media = item['media:content'] || item['media:thumbnail'] || item.enclosure;
  for (const entry of asArray(media)) {
    const url = safeUrl(entry && (entry['@_url'] || entry.url || entry['@_href']));
    if (url) return url;
  }
  const html = nodeText(item.description || item['content:encoded'] || item.summary);
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return match ? safeUrl(match[1]) : null;
}

function extractMetaImage(html) {
  const patterns = [
    /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
    /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i,
  ];
  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match) {
      const url = safeUrl(match[1].replace(/&amp;/g, '&'));
      if (url) return url;
    }
  }
  return null;
}

async function fetchText(url, timeoutMs = 15_000) {
  const response = await fetch(url, {
    redirect: 'follow',
    headers: {
      'User-Agent': USER_AGENT,
      Accept: 'application/rss+xml, application/xml, text/xml, text/html;q=0.9, */*;q=0.8',
    },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) {
    const error = new Error(`Upstream returned HTTP ${response.status}`);
    error.status = response.status;
    throw error;
  }
  return response.text();
}

// The public Overpass endpoint is reliable with Node's https module but can
// stall with undici/fetch on some networks. Keep this separate path explicit.
function httpsGetJson(url, timeoutMs = 35_000) {
  return new Promise((resolve, reject) => {
    const request = https.request(
      url,
      {
        method: 'GET',
        family: 4,
        headers: {
          'User-Agent': USER_AGENT,
          Accept: 'application/json',
          Connection: 'close',
        },
        timeout: timeoutMs,
      },
      (response) => {
        if (!response.statusCode || response.statusCode < 200 || response.statusCode >= 300) {
          response.resume();
          const error = new Error(`Upstream returned HTTP ${response.statusCode || 'unknown'}`);
          error.status = response.statusCode;
          reject(error);
          return;
        }
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => {
          body += chunk;
          if (body.length > 8_000_000) request.destroy(new Error('Response too large'));
        });
        response.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch (error) {
            reject(error);
          }
        });
      },
    );
    request.on('timeout', () => request.destroy(new Error('Overpass request timed out')));
    request.on('error', reject);
    request.end();
  });
}

function parseGoogleNews(xml, category, locale) {
  const parsed = xmlParser.parse(xml);
  const channel = parsed?.rss?.channel || parsed?.feed;
  const items = asArray(channel?.item || channel?.entry);
  const articles = [];

  for (const item of items) {
    const title = cleanText(nodeText(item.title), 220);
    const link = safeUrl(nodeText(item.link) || nodeText(item.guid) || nodeText(item.id));
    if (!title || !link) continue;

    const sourceName = cleanText(
      nodeText(item.source) || nodeText(item.author) || (locale === 'en' ? 'Google News' : 'Google News'),
      80,
    );
    let summary = cleanText(
      nodeText(item.description) || nodeText(item.summary) || nodeText(item['content:encoded']),
      320,
    );
    if (summary.toLowerCase() === title.toLowerCase()) summary = '';
    const titleSuffix = ` - ${sourceName}`;
    const cleanTitle = title.endsWith(titleSuffix)
      ? title.slice(0, -titleSuffix.length).trim()
      : title;

    articles.push({
      id: cleanText(nodeText(item.guid) || nodeText(item.id) || link, 220),
      title: cleanTitle,
      source: sourceName,
      publishedAt: parseDate(item.pubDate || item.published || item.updated),
      summary,
      severity: /outbreak|alert|emergency|recall/i.test(cleanTitle) ? 'CRITICAL' : 'ADVISORY',
      link,
      language: locale,
      thumbnail: extractImage(item),
      category,
    });
  }
  return articles;
}

async function enrichImages(articles) {
  const candidates = articles.filter((article) => !article.thumbnail).slice(0, 6);
  await Promise.allSettled(
    candidates.map(async (article) => {
      try {
        const html = await fetchText(article.link, 4_500);
        const image = extractMetaImage(html);
        if (image) article.thumbnail = image;
      } catch (_) {
        // Images are optional. Never fail a news request because a publisher
        // blocks image extraction.
      }
    }),
  );
  return articles;
}

async function handleNews(url, res) {
  const category = CATEGORY_QUERIES[url.searchParams.get('category')] ? url.searchParams.get('category') : 'all';
  const lang = NEWS_LOCALES[url.searchParams.get('lang')] ? url.searchParams.get('lang') : 'en';
  const page = Math.max(1, Math.min(20, Number(url.searchParams.get('page') || 1) || 1));
  const limit = Math.max(1, Math.min(30, Number(url.searchParams.get('limit') || 12) || 12));
  const locale = NEWS_LOCALES[lang];
  const query =
    (LOCAL_CATEGORY_QUERIES[lang] && LOCAL_CATEGORY_QUERIES[lang][category]) ||
    CATEGORY_QUERIES[category];

  const cacheKey = `news:${lang}:${category}:${page}:${limit}`;
  const cached = getCache(cacheKey);
  if (cached) return sendJson(res, 200, cached);

  const isHealthTopic = category === 'all';
  const upstream = new URL(
    isHealthTopic
      ? 'https://news.google.com/rss/headlines/section/topic/HEALTH'
      : 'https://news.google.com/rss/search',
  );
  if (!isHealthTopic) upstream.searchParams.set('q', query);
  upstream.searchParams.set('hl', locale.hl);
  upstream.searchParams.set('gl', locale.gl);
  upstream.searchParams.set('ceid', locale.ceid);

  try {
    const xml = await fetchText(upstream.toString(), 20_000);
    let all = parseGoogleNews(xml, category, lang);
    const seen = new Set();
    all = all.filter((article) => {
      if (seen.has(article.id)) return false;
      seen.add(article.id);
      return true;
    });
    const start = (page - 1) * limit;
    const pageArticles = await enrichImages(all.slice(start, start + limit));
    const payload = {
      articles: pageArticles,
      page,
      limit,
      total: all.length,
      hasMore: start + limit < all.length,
      lastUpdated: new Date().toISOString(),
      source: 'Google News RSS',
      category,
      language: lang,
      warning: all.length === 0 ? 'No live articles were returned by the source.' : undefined,
    };
    if (pageArticles.length > 0) setCache(cacheKey, payload, NEWS_TTL);
    return sendJson(res, 200, payload);
  } catch (error) {
    const status = error.status === 429 ? 429 : 502;
    return sendError(
      res,
      status,
      status === 429
        ? 'The news source is rate-limiting requests. Try again shortly.'
        : 'The live news source could not be reached.',
      status === 429 ? 'rate_limited' : 'news_unavailable',
    );
  }
}

function handleCampaigns(res) {
  const cacheKey = 'campaigns:verified';
  const cached = getCache(cacheKey);
  if (cached) return sendJson(res, 200, cached);

  try {
    const raw = fs.readFileSync(CAMPAIGNS_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    const campaigns = Array.isArray(parsed) ? parsed : parsed.campaigns;
    if (!Array.isArray(campaigns) || campaigns.length === 0) {
      return sendError(res, 503, 'The verified campaign dataset is empty.', 'campaigns_unavailable');
    }
    const payload = {
      campaigns,
      source: parsed.sourceNote || 'Verified WHO/UN public-health observance calendar',
      lastUpdated: parsed.lastReviewed || new Date().toISOString().slice(0, 10),
      lastReviewed: parsed.lastReviewed,
      warning: undefined,
    };
    setCache(cacheKey, payload, 60 * 60 * 1000);
    return sendJson(res, 200, payload);
  } catch (_) {
    return sendError(res, 500, 'The verified campaign dataset could not be read.', 'campaigns_unavailable');
  }
}

async function handleGeocode(url, res) {
  const query = cleanText(url.searchParams.get('q'), 120);
  const limit = Math.max(1, Math.min(10, Number(url.searchParams.get('limit') || 5) || 5));
  if (query.length < 2) {
    return sendError(res, 400, 'Enter at least two characters to search for a place.', 'invalid_request');
  }
  const cacheKey = `geocode:${query.toLowerCase()}:${limit}`;
  const cached = getCache(cacheKey);
  if (cached) return sendJson(res, 200, cached);

  const upstream = new URL(NOMINATIM_ENDPOINT);
  upstream.searchParams.set('format', 'jsonv2');
  upstream.searchParams.set('limit', String(limit));
  upstream.searchParams.set('addressdetails', '1');
  upstream.searchParams.set('q', query);

  try {
    const response = await fetch(upstream, {
      redirect: 'follow',
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'application/json',
        'Accept-Language': 'en',
      },
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      return sendError(
        res,
        response.status === 429 ? 429 : 502,
        'The place search service is unavailable. Try again shortly.',
        'geocode_unavailable',
      );
    }
    const results = await response.json();
    const payload = {
      results: Array.isArray(results)
        ? results.map((place) => ({
            display_name: cleanText(place.display_name, 300),
            name: cleanText(place.name || place.display_name, 200),
            lat: Number(place.lat),
            lon: Number(place.lon),
            type: place.type || '',
            category: place.category || '',
            address: place.address || {},
          }))
        : [],
      source: 'OpenStreetMap Nominatim',
      lastUpdated: new Date().toISOString(),
    };
    setCache(cacheKey, payload, GEOCODE_TTL);
    return sendJson(res, 200, payload);
  } catch (_) {
    return sendError(res, 502, 'The place search service could not be reached.', 'geocode_unavailable');
  }
}

function amenityFilter(type) {
  switch (type) {
    case 'hospital':
      return 'hospital';
    case 'clinic':
      return 'clinic|doctors';
    case 'pharmacy':
      return 'pharmacy';
    default:
      return 'hospital|clinic|doctors|pharmacy';
  }
}

function asNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRadians = (degrees) => (degrees * Math.PI) / 180;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, a))));
}

function facilityFromNominatim(result, originLat, originLon, requestedType) {
  const lat = asNumber(result.lat);
  const lon = asNumber(result.lon);
  if (!lat || !lon) return null;

  const address =
    result.address && typeof result.address === 'object' ? result.address : {};
  const addressParts = [
    address.house_number,
    address.road,
    address.neighbourhood,
    address.suburb,
    address.city || address.town || address.village,
    address.postcode,
  ]
    .filter((value) => value && String(value).trim())
    .map((value) => String(value).trim());
  const displayName = cleanText(result.display_name, 300);
  const rawType = String(result.type || '').toLowerCase();
  let type = '';
  if (rawType.includes('pharmacy')) type = 'pharmacy';
  else if (rawType.includes('hospital')) type = 'hospital';
  else if (
    rawType.includes('clinic') ||
    rawType.includes('doctor') ||
    rawType.includes('dispensary') ||
    rawType.includes('medical_centre') ||
    rawType.includes('health_centre')
  ) {
    type = 'clinic';
  }
  // Never label a Nominatim result as a hospital or clinic unless its OSM
  // type confirms it. This prevents unrelated search matches from appearing
  // as healthcare facilities.
  if (!type) return null;
  if (requestedType !== 'all' && type !== requestedType) return null;

  const name = cleanText(
    result.name || (displayName ? displayName.split(',')[0] : ''),
    160,
  );
  if (!name) return null;

  const extratags =
    result.extratags && typeof result.extratags === 'object' ? result.extratags : {};
  return {
    id: `nominatim:${result.osm_type || ''}:${result.osm_id || result.place_id || `${lat},${lon}`}`,
    name,
    type,
    address: addressParts.length
      ? addressParts.join(', ')
      : displayName || 'Address not listed in OpenStreetMap',
    phone: cleanText(extratags.phone || extratags['contact:phone'], 40) || null,
    website: safeUrl(extratags.website || extratags['contact:website']),
    lat,
    lon,
    distanceKm: Number(haversineKm(originLat, originLon, lat, lon).toFixed(2)),
    openingHours: cleanText(extratags.opening_hours, 120) || null,
  };
}

async function fetchNominatimFacilities(latitude, longitude, radiusKm, type) {
  const latDelta = radiusKm / 111.32;
  const lonDelta =
    radiusKm / (111.32 * Math.max(0.01, Math.cos((latitude * Math.PI) / 180)));
  const viewbox = [
    longitude - lonDelta,
    latitude + latDelta,
    longitude + lonDelta,
    latitude - latDelta,
  ].join(',');

  const queries =
    type === 'all' ? ['hospital', 'clinic', 'pharmacy'] : [type];
  const facilities = new Map();

  for (let index = 0; index < queries.length; index++) {
    const query = queries[index];
    const upstream = new URL(NOMINATIM_ENDPOINT);
    upstream.searchParams.set('format', 'jsonv2');
    upstream.searchParams.set('limit', '40');
    upstream.searchParams.set('addressdetails', '1');
    upstream.searchParams.set('extratags', '1');
    upstream.searchParams.set('bounded', '1');
    upstream.searchParams.set('viewbox', viewbox);
    upstream.searchParams.set('q', query);

    const response = await fetch(upstream, {
      redirect: 'follow',
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'application/json',
        'Accept-Language': 'en',
      },
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) {
      throw new Error(`Nominatim returned HTTP ${response.status}`);
    }
    const results = await response.json();
    for (const result of Array.isArray(results) ? results : []) {
      const facility = facilityFromNominatim(
        result,
        latitude,
        longitude,
        type === 'all' ? query : type,
      );
      if (facility) facilities.set(facility.id, facility);
    }

    // The public Nominatim policy allows at most one request per second.
    if (index < queries.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, 1_100));
    }
  }

  return [...facilities.values()]
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, 80);
}

function facilityFromElement(element, originLat, originLon) {
  const tags = element.tags && typeof element.tags === 'object' ? element.tags : {};
  const lat = asNumber(element.lat ?? element.center?.lat);
  const lon = asNumber(element.lon ?? element.center?.lon);
  if (!lat || !lon) return null;

  const type = String(tags.amenity || tags.healthcare || 'hospital');
  const addressParts = [
    tags['addr:housenumber'],
    tags['addr:street'],
    tags['addr:suburb'],
    tags['addr:city'],
    tags['addr:postcode'],
  ]
    .filter((value) => value && String(value).trim())
    .map((value) => String(value).trim());
  const name = cleanText(
    tags.name || tags['name:en'] || tags.operator || `Unnamed ${type} (OpenStreetMap)`,
    160,
  );
  const website = safeUrl(tags.website || tags['contact:website']);
  return {
    id: String(element.id ?? `${lat},${lon}`),
    name,
    type: type === 'doctors' ? 'doctors' : type,
    address: addressParts.length ? addressParts.join(', ') : 'Address not listed in OpenStreetMap',
    phone: cleanText(tags.phone || tags['contact:phone'], 40) || null,
    website,
    lat,
    lon,
    distanceKm: Number(haversineKm(originLat, originLon, lat, lon).toFixed(2)),
    openingHours: cleanText(tags.opening_hours, 120) || null,
  };
}

async function handleFacilities(url, res) {
  const latitude = Number(url.searchParams.get('lat'));
  const longitude = Number(url.searchParams.get('lon'));
  const radiusKm = Math.max(1, Math.min(30, Number(url.searchParams.get('radius') || 8) || 8));
  const requestedType = url.searchParams.get('type') || 'all';
  const type = ['hospital', 'clinic', 'pharmacy', 'all'].includes(requestedType)
    ? requestedType
    : 'all';

  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    return sendError(res, 400, 'A valid latitude is required.', 'invalid_request');
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    return sendError(res, 400, 'A valid longitude is required.', 'invalid_request');
  }

  const cacheKey = `facilities:${latitude.toFixed(3)}:${longitude.toFixed(3)}:${radiusKm}:${type}`;
  const cached = getCache(cacheKey);
  if (cached) return sendJson(res, 200, cached);

  const radiusMeters = Math.round(radiusKm * 1000);
  const overpassQuery = `
[out:json][timeout:45];
(
  node["amenity"~"${amenityFilter(type)}"](around:${radiusMeters},${latitude},${longitude});
  way["amenity"~"${amenityFilter(type)}"](around:${radiusMeters},${latitude},${longitude});
  relation["amenity"~"${amenityFilter(type)}"](around:${radiusMeters},${latitude},${longitude});
);
out center tags 80;
`.trim();

  let emptyResult = false;
  const overpassAttempt = (async () => {
    // The public Overpass endpoint is most reliable with a GET request and a
    // descriptive User-Agent. A POST body is sometimes rejected or queued for
    // much longer by the shared instance.
    const upstream = new URL(OVERPASS_ENDPOINT);
    upstream.searchParams.set('data', overpassQuery);
    const decoded = await httpsGetJson(upstream, 12_000);
    const elements = Array.isArray(decoded.elements) ? decoded.elements : [];
    const facilities = elements
      .map((element) => facilityFromElement(element, latitude, longitude))
      .filter(Boolean)
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, 80);
    if (facilities.length === 0) {
      emptyResult = true;
      throw new Error('Overpass returned no facilities');
    }
    return { facilities, source: 'OpenStreetMap / Overpass API' };
  })();

  // Overpass can be slow or queued. The public Nominatim index exposes the same
  // OpenStreetMap data, so race both and use whichever returns real results
  // first. This keeps the page responsive without inventing facilities.
  const nominatimAttempt = fetchNominatimFacilities(
    latitude,
    longitude,
    radiusKm,
    type,
  ).then((facilities) => {
    if (facilities.length === 0) {
      emptyResult = true;
      throw new Error('Nominatim returned no facilities');
    }
    return {
      facilities,
      source: 'OpenStreetMap / Nominatim',
      warning:
        'Live results came from the OpenStreetMap Nominatim index because the Overpass service was slow or unavailable.',
    };
  });

  try {
    const result = await Promise.any([overpassAttempt, nominatimAttempt]);
    const payload = {
      facilities: result.facilities,
      source: result.source,
      lastUpdated: new Date().toISOString(),
      warning: result.warning,
      attribution: '© OpenStreetMap contributors, ODbL',
    };
    setCache(cacheKey, payload, FACILITY_TTL);
    return sendJson(res, 200, payload);
  } catch (_) {
    if (emptyResult) {
      return sendJson(res, 200, {
        facilities: [],
        source: 'OpenStreetMap',
        lastUpdated: new Date().toISOString(),
        warning: 'OpenStreetMap returned no matching facilities for this area.',
        attribution: '© OpenStreetMap contributors, ODbL',
      });
    }
    return sendError(
      res,
      502,
      'The OpenStreetMap facility service could not be reached. Try again or open an external map.',
      'facilities_unavailable',
    );
  }
}

const server = http.createServer(async (req, res) => {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }
  if (req.method !== 'GET') {
    return sendError(res, 405, 'Only GET requests are supported.', 'method_not_allowed');
  }
  if (!allowRequest(req)) {
    res.setHeader('Retry-After', '60');
    return sendError(res, 429, 'Too many requests. Please wait a minute.', 'rate_limited');
  }

  let url;
  try {
    url = new URL(req.url, `http://${req.headers.host || `localhost:${PORT}`}`);
  } catch (_) {
    return sendError(res, 400, 'Invalid request URL.', 'invalid_request');
  }

  switch (url.pathname) {
    case '/api/health':
      return sendJson(res, 200, {
        status: 'ok',
        service: 'healthmate-proxy',
        version: '1.0.0',
        uptimeSeconds: Math.round(process.uptime()),
        sources: {
          news: 'Google News RSS',
          campaigns: 'Bundled WHO/UN verified dataset',
          geocode: 'OpenStreetMap Nominatim',
          facilities: 'OpenStreetMap Overpass API',
        },
        lastUpdated: new Date().toISOString(),
      });
    case '/api/news':
      return handleNews(url, res);
    case '/api/campaigns':
      return handleCampaigns(res);
    case '/api/geocode':
      return handleGeocode(url, res);
    case '/api/facilities':
      return handleFacilities(url, res);
    default:
      return sendError(res, 404, 'Unknown endpoint.', 'not_found');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`HealthMate proxy listening on http://localhost:${PORT}`);
  console.log('Endpoints: /api/health, /api/news, /api/campaigns, /api/geocode, /api/facilities');
  console.log(`CORS origin: ${ALLOWED_ORIGIN}`);
});

function shutdown(signal) {
  console.log(`\n${signal} received. Closing proxy.`);
  server.close(() => process.exit(0));
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
