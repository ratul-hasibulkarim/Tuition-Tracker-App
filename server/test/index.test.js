import assert from 'node:assert/strict';
import { test } from 'node:test';

import { handle } from '../src/index.js';

const env = { APP_TOKEN: 'secret', MAPS_API_KEY: 'maps', AI_API_KEY: 'ai' };

function req(path, body, token = 'secret') {
  return new Request(`https://api.example.com${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-App-Token': token },
    body: JSON.stringify(body),
  });
}

function fakeFetch(responses) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init, body: JSON.parse(init.body) });
    const next = responses.shift();
    return new Response(JSON.stringify(next.body), { status: next.status ?? 200 });
  };
  return { impl, calls };
}

const A = { lat: 23.75, lng: 90.37 };
const B = { lat: 23.78, lng: 90.41 };

test('rejects requests without the app token', async () => {
  const res = await handle(req('/v1/route', {}, 'wrong'), env, fakeFetch([]).impl);
  assert.equal(res.status, 401);
});

test('route returns km and minutes from the Routes API', async () => {
  const f = fakeFetch([{ body: { routes: [{ distanceMeters: 7200, duration: '1500s' }] } }]);
  const res = await handle(req('/v1/route', { origin: A, destination: B }), env, f.impl);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { km: 7.2, minutes: 25, mode: 'TWO_WHEELER', live: true });
  assert.equal(f.calls[0].init.headers['X-Goog-Api-Key'], 'maps');
  assert.equal(f.calls[0].body.travelMode, 'TWO_WHEELER');
});

test('route falls back to DRIVE when two-wheeler fails', async () => {
  const f = fakeFetch([
    { status: 400, body: {} },
    { body: { routes: [{ distanceMeters: 1000, duration: '120s' }] } },
  ]);
  const res = await handle(req('/v1/route', { origin: A, destination: B }), env, f.impl);
  assert.equal((await res.json()).mode, 'DRIVE');
  assert.equal(f.calls[1].body.travelMode, 'DRIVE');
});

test('route validates points', async () => {
  const res = await handle(req('/v1/route', { origin: A, destination: { lat: 'x' } }), env,
    fakeFetch([]).impl);
  assert.equal(res.status, 400);
});

test('route matrix builds square matrices', async () => {
  const f = fakeFetch([{
    body: [
      { originIndex: 0, destinationIndex: 1, duration: '600s', distanceMeters: 3000, condition: 'ROUTE_EXISTS' },
      { originIndex: 1, destinationIndex: 0, duration: '660s', distanceMeters: 3100, condition: 'ROUTE_EXISTS' },
      { originIndex: 0, destinationIndex: 0, condition: 'ROUTE_EXISTS' },
      { originIndex: 1, destinationIndex: 1, condition: 'ROUTE_EXISTS' },
    ],
  }]);
  const res = await handle(req('/v1/route-matrix', { points: [A, B] }), env, f.impl);
  const data = await res.json();
  assert.deepEqual(data.minutes, [[0, 10], [11, 0]]);
  assert.deepEqual(data.km, [[0, 3], [3.1, 0]]);
});

test('route matrix limits the number of points', async () => {
  const points = Array.from({ length: 11 }, () => A);
  const res = await handle(req('/v1/route-matrix', { points }), env, fakeFetch([]).impl);
  assert.equal(res.status, 400);
});

test('ai chat forwards to an OpenAI-compatible provider', async () => {
  const f = fakeFetch([{ body: { choices: [{ message: { content: 'Plan text' } }] } }]);
  const res = await handle(
    req('/v1/ai/chat', { messages: [{ role: 'user', content: 'Hi' }] }), env, f.impl);
  assert.deepEqual(await res.json(), { text: 'Plan text' });
  assert.match(f.calls[0].url, /generativelanguage.*\/chat\/completions$/);
  assert.equal(f.calls[0].init.headers.Authorization, 'Bearer ai');
  assert.equal(f.calls[0].body.model, 'gemini-2.5-flash');
});

test('ai chat rejects oversized requests', async () => {
  const res = await handle(
    req('/v1/ai/chat', { messages: [{ role: 'user', content: 'x'.repeat(20001) }] }), env,
    fakeFetch([]).impl);
  assert.equal(res.status, 413);
});

test('rate limiter blocks when exhausted', async () => {
  const limited = { ...env, RATE_LIMITER: { limit: async () => ({ success: false }) } };
  const res = await handle(req('/v1/route', { origin: A, destination: B }), limited,
    fakeFetch([]).impl);
  assert.equal(res.status, 429);
});
