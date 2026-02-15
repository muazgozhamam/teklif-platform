/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Dashboard HTTP client
 * - `api<T>(path, init?)` callable fetch wrapper
 * - `api.get/post/patch/delete` axios-like helpers returning { data, status, ok, headers }
 */

export type ApiResponse<T = unknown> = {
  data: T;
  status: number;
  ok: boolean;
  headers: Headers;
};


export type ApiInit = RequestInit & {
  params?: Record<string, unknown>;
};
export type ApiClient = {
  <T = any>(path: string, init?: ApiInit): Promise<T>;
  get<T = any>(path: string, init?: ApiInit): Promise<ApiResponse<T>>;
  post<T = any>(path: string, body?: any, init?: ApiInit): Promise<ApiResponse<T>>;
  patch<T = any>(path: string, body?: any, init?: ApiInit): Promise<ApiResponse<T>>;
  put<T = any>(path: string, body?: any, init?: ApiInit): Promise<ApiResponse<T>>;
  delete<T = any>(path: string, init?: ApiInit): Promise<ApiResponse<T>>;
};

const TOKEN_KEY = 'accessToken';

export function setToken(token: string) {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(TOKEN_KEY, token);

  if (typeof document !== 'undefined') document.cookie = `accessToken=${encodeURIComponent(token)}; Path=/; SameSite=Lax`;
}

export function clearToken() {
  if (typeof window === 'undefined') return;
  window.localStorage.removeItem(TOKEN_KEY);

  if (typeof document !== 'undefined') document.cookie = "accessToken=; Path=/; Max-Age=0; SameSite=Lax";
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

function resolveBaseUrl() {
  // Prefer explicit env, fallback to localhost API for dev
  const base =
    process.env.NEXT_PUBLIC_API_BASE_URL ||
    process.env.NEXT_PUBLIC_API_URL ||
    process.env.API_URL ||
    'http://localhost:3001';
  return base.replace(/\/+$/, '');
}

function withAuth(init?: ApiInit): RequestInit {
  const token = getToken();
  const headers = new Headers(init?.headers || {});
  if (token && !headers.has('Authorization')) headers.set('Authorization', `Bearer ${token}`);
  if (!headers.has('Accept')) headers.set('Accept', 'application/json');
  return { ...init, headers };
}


function appendParamsToUrl(url: string, init?: ApiInit): { url: string; init: ApiInit | undefined } {
  const anyInit = (init || {}) as any;
  const params = anyInit.params as Record<string, unknown> | undefined;
  if (!params || typeof params !== 'object') return { url, init };

  const usp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null) continue;
    usp.set(k, String(v));
  }
  const qs = usp.toString();
  if (!qs) {
// eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { params: _p, ...rest } = anyInit;
    return { url, init: rest as RequestInit };
  }

  const joiner = url.includes('?') ? '&' : '?';
  const nextUrl = url + joiner + qs;

// eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { params: _p, ...rest } = anyInit;
  return { url: nextUrl, init: rest as RequestInit };
}


async function parseBody(res: Response) {
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return res.json();
  const text = await res.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}

async function requestJson<T = any>(
  method: string,
  path: string,
  body?: any,
  init: ApiInit = {},
): Promise<ApiResponse<T>> {
  const headers = new Headers(init.headers || {});
  let finalBody: BodyInit | undefined = init.body as any;

  if (body !== undefined) {
    if (typeof body === 'string' || body instanceof FormData) {
      finalBody = body as any;
    } else {
      finalBody = JSON.stringify(body);
      if (!headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
    }
  }

  const base = resolveBaseUrl();
  const rawUrl = path.startsWith('http') ? path : `${base}${path}`;
  const { url, init: init2 } = appendParamsToUrl(rawUrl, init);

  const res = await fetch(url, withAuth({ ...(init2 || init), method, headers, body: finalBody }));
  const data = (await parseBody(res)) as T;

  if (!res.ok) {
    if (res.status === 401) {
      try { clearToken(); } catch {}
      if (typeof window !== 'undefined') window.location.href = '/login';
    }

    throw Object.assign(new Error('API request failed'), { status: res.status, data });
  }

  return { data, status: res.status, ok: res.ok, headers: res.headers };
}

// callable base (generic fetch wrapper)
const baseCallable = async function apiCallable<T = any>(path: string, init: ApiInit = {}): Promise<T> {
  const base = resolveBaseUrl();
  const rawUrl = path.startsWith('http') ? path : `${base}${path}`;
  const { url, init: init2 } = appendParamsToUrl(rawUrl, init);
  const res = await fetch(url, withAuth(init2 || init));

  if (!res.ok) {
    if (res.status === 401) {
      try { clearToken(); } catch {}
      if (typeof window !== 'undefined') window.location.href = '/login';
    }

    const body = await parseBody(res);
    throw Object.assign(new Error('API request failed'), { status: res.status, body });
  }
  return (await parseBody(res)) as T;
};

// Final exported client with correct TS shape
export const api: ApiClient = Object.assign(baseCallable, {
  get<T = any>(path: string, init?: ApiInit) {
    return requestJson<T>('GET', path, undefined, init);
  },
  post<T = any>(path: string, body?: any, init?: ApiInit) {
    return requestJson<T>('POST', path, body, init);
  },
  patch<T = any>(path: string, body?: any, init?: ApiInit) {
    return requestJson<T>('PATCH', path, body, init);
  },
put<T = any>(path: string, body?: any, init?: ApiInit) {
  return requestJson<T>('PUT', path, body, init);
},
  delete<T = any>(path: string, init?: ApiInit) {
    return requestJson<T>('DELETE', path, undefined, init);
  },
});

// Optional named helpers if needed elsewhere
export const apiGet = api.get;
export const apiPost = api.post;
export const apiPatch = api.patch;
export const apiDelete = api.delete;
