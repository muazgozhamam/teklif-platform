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

export type ApiClient = {
  <T = any>(path: string, init?: RequestInit): Promise<T>;
  get<T = any>(path: string, init?: RequestInit): Promise<ApiResponse<T>>;
  post<T = any>(path: string, body?: any, init?: RequestInit): Promise<ApiResponse<T>>;
  patch<T = any>(path: string, body?: any, init?: RequestInit): Promise<ApiResponse<T>>;
  delete<T = any>(path: string, init?: RequestInit): Promise<ApiResponse<T>>;
};

const TOKEN_KEY = 'teklif_token';

export function setToken(token: string) {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  if (typeof window === 'undefined') return;
  window.localStorage.removeItem(TOKEN_KEY);
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

function resolveBaseUrl() {
  // Prefer explicit env, fallback to same-origin
  return process.env.NEXT_PUBLIC_API_URL?.replace(/\/+$/, '') || '';
}

function withAuth(init?: RequestInit): RequestInit {
  const token = getToken();
  const headers = new Headers(init?.headers || {});
  if (token && !headers.has('Authorization')) headers.set('Authorization', `Bearer ${token}`);
  if (!headers.has('Accept')) headers.set('Accept', 'application/json');
  return { ...init, headers };
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
  init: RequestInit = {},
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
  const url = path.startsWith('http') ? path : `${base}${path}`;

  const res = await fetch(url, withAuth({ ...init, method, headers, body: finalBody }));
  const data = (await parseBody(res)) as T;

  if (!res.ok) {
    throw Object.assign(new Error('API request failed'), { status: res.status, data });
  }

  return { data, status: res.status, ok: res.ok, headers: res.headers };
}

// callable base (generic fetch wrapper)
const baseCallable = async function apiCallable<T = any>(path: string, init: RequestInit = {}): Promise<T> {
  const base = resolveBaseUrl();
  const url = path.startsWith('http') ? path : `${base}${path}`;
  const res = await fetch(url, withAuth(init));

  if (!res.ok) {
    const body = await parseBody(res);
    throw Object.assign(new Error('API request failed'), { status: res.status, body });
  }
  return (await parseBody(res)) as T;
};

// Final exported client with correct TS shape
export const api: ApiClient = Object.assign(baseCallable, {
  get<T = any>(path: string, init?: RequestInit) {
    return requestJson<T>('GET', path, undefined, init);
  },
  post<T = any>(path: string, body?: any, init?: RequestInit) {
    return requestJson<T>('POST', path, body, init);
  },
  patch<T = any>(path: string, body?: any, init?: RequestInit) {
    return requestJson<T>('PATCH', path, body, init);
  },
  delete<T = any>(path: string, init?: RequestInit) {
    return requestJson<T>('DELETE', path, undefined, init);
  },
});

// Optional named helpers if needed elsewhere
export const apiGet = api.get;
export const apiPost = api.post;
export const apiPatch = api.patch;
export const apiDelete = api.delete;
