// All calls go to /api/... — proxied by nginx to the API container

function getToken() { return localStorage.getItem('chronicler_token'); }
export function setToken(t) { localStorage.setItem('chronicler_token', t); }
export function clearToken() { localStorage.removeItem('chronicler_token'); }
export function isLoggedIn() { return !!getToken(); }

async function apiFetch(path, options = {}) {
  const token = getToken();
  const headers = { 'Content-Type': 'application/json', ...options.headers };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(path, { ...options, headers });
  if (res.status === 401) {
    clearToken();
    window.location.href = '/login';
    throw new Error('Unauthorized');
  }
  return res;
}

export const auth = {
  async login(email, password) {
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    if (!res.ok) return null;
    const { token } = await res.json();
    setToken(token);
    return token;
  },
  async register(email, password) {
    const res = await fetch('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    if (!res.ok) return null;
    const { token } = await res.json();
    setToken(token);
    return token;
  },
  logout() { clearToken(); window.location.href = '/login'; }
};

export const booksApi = {
  async list(q, { root = false } = {}) {
    let url = '/api/books';
    if (q) url += `?q=${encodeURIComponent(q)}`;
    else if (root) url += '?root=true';
    const res = await apiFetch(url);
    return res.json();
  },
  async get(id) {
    const res = await apiFetch(`/api/books/${id}`);
    return res.json();
  },
  coverUrl: (id) => `/api/books/${id}/cover`,
  async favorite(id) {
    const res = await apiFetch(`/api/books/${id}/favorite`, { method: 'POST' });
    return res.json(); // { isFavorite }
  },
  async chapters(id) {
    const res = await apiFetch(`/api/books/${id}/chapters`);
    return res.json();
  },
  async scan() {
    const res = await apiFetch('/api/library/scan', { method: 'POST' });
    return res.json();
  },
  async enrich() {
    const res = await apiFetch('/api/library/enrich', { method: 'POST' });
    return res.json();
  },
  async clearCover(id) {
    await apiFetch(`/api/books/${id}/cover`, { method: 'DELETE' });
  },
  async refetchCover(id) {
    const res = await apiFetch(`/api/books/${id}/refetch-cover`, { method: 'POST' });
    return res.json();
  },
  async scanPreview() {
    const res = await apiFetch('/api/library/scan/preview');
    return res.json();
  },
  async scan() {
    const res = await apiFetch('/api/library/scan', { method: 'POST' });
    return res.json();
  },
  async resetProgress(id) {
    await apiFetch(`/api/books/${id}/reset`, { method: 'POST' });
  },
  async saveMeta(id, { title, author, narrator, year, description }) {
    await apiFetch(`/api/books/${id}/meta`, {
      method: 'PUT',
      body: JSON.stringify({ title, author, narrator, description, year })
    });
  }
};

export const collectionsApi = {
  async list() {
    const res = await apiFetch('/api/collections');
    return res.json();
  },
  async get(id) {
    const res = await apiFetch(`/api/collections/${id}`);
    return res.json();
  },
  async books(id) {
    const res = await apiFetch(`/api/collections/${id}/books`);
    return res.json();
  },
  coverUrl: (id) => `/api/collections/${id}/cover`,
  async uploadCover(id, file) {
    const formData = new FormData();
    formData.append('cover', file, file.name);
    const res = await fetch(`/api/collections/${id}/cover/upload`, {
      method: 'PUT',
      headers: { 'Authorization': `Bearer ${getToken()}` },
      body: formData,
    });
    return res.json().catch(() => null);
  },
};

export const chaptersApi = {
  audioUrl: (id) => `/api/chapters/${id}/audio`,
  async getProgress(id) {
    const res = await apiFetch(`/api/chapters/${id}/progress`);
    return res.json();
  },
  async saveProgress(id, positionSeconds, durationSeconds = 0) {
    await apiFetch(`/api/chapters/${id}/progress`, {
      method: 'PUT',
      body: JSON.stringify({ positionSeconds, durationSeconds })
    });
  },
  async reset(id) {
    await apiFetch(`/api/chapters/${id}/reset`, { method: 'POST' });
  },
  async complete(id) {
    await apiFetch(`/api/chapters/${id}/complete`, { method: 'POST' });
  },
  async update(id, { title, trackNumber }) {
    await apiFetch(`/api/chapters/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ title, trackNumber })
    });
  }
};

