import test from 'node:test';
import assert from 'node:assert/strict';
import { apiFetch, setToken, isLoggedIn, auth, collectionsApi } from './api.js';

const store = new Map();
globalThis.localStorage = { getItem: k => store.get(k) ?? null, setItem: (k,v) => store.set(k,v), removeItem: k => store.delete(k) };
globalThis.window = { location: { href: '/' } };
function reset() { store.clear(); setToken('current'); window.location.href = '/'; }

test('authenticated 401 clears session and redirects', async () => {
  reset(); globalThis.fetch = async () => new Response('', { status: 401 });
  await assert.rejects(apiFetch('/api/books'), /Unauthorized/);
  assert.equal(isLoggedIn(), false); assert.equal(window.location.href, '/login');
});
test('late 401 preserves a new login', async () => {
  reset(); globalThis.fetch = async () => { setToken('new'); return new Response('', { status: 401 }); };
  await assert.rejects(apiFetch('/api/books'));
  assert.equal(localStorage.getItem('chronicler_token'), 'new'); assert.equal(window.location.href, '/');
});
test('403 and 500 preserve session', async () => {
  for (const status of [403, 500]) {
    reset(); globalThis.fetch = async () => new Response('', { status });
    await apiFetch('/api/books'); assert.equal(isLoggedIn(), true);
  }
});
test('network failures preserve session', async () => {
  reset(); globalThis.fetch = async () => { throw new TypeError('offline'); };
  await assert.rejects(apiFetch('/api/books')); assert.equal(isLoggedIn(), true);
});
test('login 401 does not invalidate an existing session', async () => {
  reset(); globalThis.fetch = async () => new Response('', { status: 401 });
  assert.equal(await auth.login('a', 'wrong'), null); assert.equal(isLoggedIn(), true);
});
test('multipart uploads use 401 handling without a JSON content type', async () => {
  reset(); globalThis.fetch = async (_, options) => {
    assert.equal(options.headers['Content-Type'], undefined);
    assert.equal(options.headers.Authorization, 'Bearer current');
    return new Response('', { status: 401 });
  };
  const file = new Blob(['cover']); file.name = 'cover.jpg';
  await assert.rejects(collectionsApi.uploadCover(1, file)); assert.equal(isLoggedIn(), false);
});
