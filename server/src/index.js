// Tuition Tracker API proxy (Cloudflare Worker).
//
// Keeps the Google Maps and AI keys on the server so they are never shipped
// inside the app. Endpoints (all POST, JSON, need the X-App-Token header):
//   /v1/route         { origin:{lat,lng}, destination:{lat,lng} }
//   /v1/route-matrix  { points:[{lat,lng}, ...] }   (up to 10 points)
//   /v1/ai/chat       { messages:[{role, content}], maxTokens? }

const ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';
const MATRIX_URL = 'https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix';
const MAX_MATRIX_POINTS = 10;
const MAX_AI_CHARS = 20000;

// Gemini's OpenAI-compatible endpoint has a free tier. Any OpenAI-compatible
// provider works (OpenRouter, Groq, DeepSeek...) by changing AI_BASE_URL/AI_MODEL.
const DEFAULT_AI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/openai';
const DEFAULT_AI_MODEL = 'gemini-2.5-flash';

export default {
  fetch: (request, env) => handle(request, env, fetch),
};

export async function handle(request, env, fetchImpl) {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204 });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  if (!env.APP_TOKEN || request.headers.get('X-App-Token') !== env.APP_TOKEN) {
    return json({ error: 'Unauthorized' }, 401);
  }
  if (env.RATE_LIMITER) {
    const key = request.headers.get('CF-Connecting-IP') ?? 'unknown';
    const { success } = await env.RATE_LIMITER.limit({ key });
    if (!success) return json({ error: 'Too many requests' }, 429);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }

  const path = new URL(request.url).pathname;
  try {
    switch (path) {
      case '/v1/route':
        return await route(body, env, fetchImpl);
      case '/v1/route-matrix':
        return await routeMatrix(body, env, fetchImpl);
      case '/v1/ai/chat':
        return await aiChat(body, env, fetchImpl);
      default:
        return json({ error: 'Not found' }, 404);
    }
  } catch (e) {
    return json({ error: 'Upstream error', detail: String(e?.message ?? e) }, 502);
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function isPoint(p) {
  return (
    p && Number.isFinite(p.lat) && Number.isFinite(p.lng) &&
    Math.abs(p.lat) <= 90 && Math.abs(p.lng) <= 180
  );
}

const waypoint = (p) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
const seconds = (d) => Number.parseFloat(String(d ?? '0s').replace('s', '')) || 0;

async function route(body, env, fetchImpl) {
  const { origin, destination } = body ?? {};
  if (!isPoint(origin) || !isPoint(destination)) return json({ error: 'Bad points' }, 400);
  if (!env.MAPS_API_KEY) return json({ error: 'Maps not configured' }, 503);

  // Motorbike routing first; fall back to car routing where it is unsupported.
  for (const travelMode of ['TWO_WHEELER', 'DRIVE']) {
    const res = await fetchImpl(ROUTES_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': env.MAPS_API_KEY,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters',
      },
      body: JSON.stringify({
        origin: waypoint(origin),
        destination: waypoint(destination),
        travelMode,
        routingPreference: 'TRAFFIC_AWARE',
      }),
    });
    if (!res.ok) continue;
    const r = (await res.json()).routes?.[0];
    if (!r) continue;
    return json({
      km: (r.distanceMeters ?? 0) / 1000,
      minutes: seconds(r.duration) / 60,
      mode: travelMode,
      live: true,
    });
  }
  return json({ error: 'No route' }, 502);
}

async function routeMatrix(body, env, fetchImpl) {
  const points = body?.points;
  if (!Array.isArray(points) || points.length < 2 || points.length > MAX_MATRIX_POINTS ||
      !points.every(isPoint)) {
    return json({ error: `Send 2-${MAX_MATRIX_POINTS} valid points` }, 400);
  }
  if (!env.MAPS_API_KEY) return json({ error: 'Maps not configured' }, 503);

  const n = points.length;
  for (const travelMode of ['TWO_WHEELER', 'DRIVE']) {
    const res = await fetchImpl(MATRIX_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': env.MAPS_API_KEY,
        'X-Goog-FieldMask': 'originIndex,destinationIndex,duration,distanceMeters,condition',
      },
      body: JSON.stringify({
        origins: points.map((p) => ({ waypoint: waypoint(p) })),
        destinations: points.map((p) => ({ waypoint: waypoint(p) })),
        travelMode,
        routingPreference: 'TRAFFIC_AWARE',
      }),
    });
    if (!res.ok) continue;
    const elements = await res.json();
    if (!Array.isArray(elements)) continue;
    // null = no route found between those two places.
    const minutes = Array.from({ length: n }, () => Array(n).fill(null));
    const km = Array.from({ length: n }, () => Array(n).fill(null));
    for (let i = 0; i < n; i++) {
      minutes[i][i] = 0;
      km[i][i] = 0;
    }
    for (const e of elements) {
      const i = e.originIndex ?? 0;
      const j = e.destinationIndex ?? 0;
      if (e.condition !== 'ROUTE_EXISTS' || i === j) continue;
      minutes[i][j] = seconds(e.duration) / 60;
      km[i][j] = (e.distanceMeters ?? 0) / 1000;
    }
    return json({ minutes, km, mode: travelMode, live: true });
  }
  return json({ error: 'No routes' }, 502);
}

async function aiChat(body, env, fetchImpl) {
  const messages = body?.messages;
  if (!Array.isArray(messages) || messages.length === 0 ||
      !messages.every((m) => ['system', 'user', 'assistant'].includes(m?.role) &&
        typeof m.content === 'string')) {
    return json({ error: 'Bad messages' }, 400);
  }
  const size = messages.reduce((n, m) => n + m.content.length, 0);
  if (size > MAX_AI_CHARS) return json({ error: 'Request too large' }, 413);
  if (!env.AI_API_KEY) return json({ error: 'AI not configured' }, 503);

  const base = (env.AI_BASE_URL || DEFAULT_AI_BASE_URL).replace(/\/$/, '');
  const res = await fetchImpl(`${base}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.AI_API_KEY}`,
    },
    body: JSON.stringify({
      model: env.AI_MODEL || DEFAULT_AI_MODEL,
      messages,
      max_tokens: Math.min(Number(body.maxTokens) || 1500, 3000),
      temperature: 0.4,
    }),
  });
  if (!res.ok) {
    return json({ error: 'AI provider error', status: res.status }, 502);
  }
  const data = await res.json();
  const text = data.choices?.[0]?.message?.content ?? '';
  return json({ text });
}
