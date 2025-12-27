#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_TS="$ROOT/apps/dashboard/lib/api.ts"

echo "==> ROOT=$ROOT"
echo "==> Rewriting: $API_TS"

mkdir -p "$(dirname "$API_TS")"

cat > "$API_TS" <<'TS'
/**
 * Dashboard HTTP client
 * - Provides a callable fetch wrapper: api<T>(path, init?)
 * - Also provides axios-like helpers: api.get/post/patch/delete returning { data, status, ok, headers }
 */

export type ApiResponse<T = unknown> = {
  data: T;
  status: number;
  ok: boolean;
  headers: Headers;
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
  // Prefer explicit env, fallback to same-origin Next API routes
  return process.env.NEXT_PUBLIC_API_URL?.replace(/\/+$/, '') || '';
}

function withAuth(init?: RequestInit): RequestInit {
  const token = getToken();
  const headers = new Headers(init?.headers || {});
  if (token && !headers.has('Authorization')) headers.set('Authorization', `Bearer ${token}`);
  // Always allow JSON by default
  if (!headers.has('Accept')) headers.set('Accept', 'application/json');
  return { ...init, headers };
}

async function parseBody(res: Response) {
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return res.json();
  // for empty responses (204 etc.)
  const text = await res.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}

/**
 * Callable API function (fetch wrapper)
 * Usage: await api<MyType>('/path', { method: 'POST', body: JSON.stringify(...) })
 */
export async function api<T = any>(path: string, init: RequestInit = {}): Promise<T> {
  const base = resolveBaseUrl();
  const url = path.startsWith('http') ? path : `${base}${path}`;
  const res = await fetch(url, withAuth(init));
  if (!res.ok) {
    const body = await parseBody(res);
    throw Object.assign(new Error('API request failed'), { status: res.status, body });
  }
  return (await parseBody(res)) as T;
}

// axios-like helpers (return {data})
async function requestJson<T = any>(method: string, path: string, body?: any, init: RequestInit = {}): Promise<ApiResponse<T>> {
  const headers = new Headers(init.headers || {});
  // If we pass an object, stringify and set content-type
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

// Attach helpers onto the callable function (hybrid)
(api as any).get = function get<T = any>(path: string, init?: RequestInit) {
  return requestJson<T>('GET', path, undefined, init);
};
(api as any).post = function post<T = any>(path: string, body?: any, init?: RequestInit) {
  return requestJson<T>('POST', path, body, init);
};
(api as any).patch = function patch<T = any>(path: string, body?: any, init?: RequestInit) {
  return requestJson<T>('PATCH', path, body, init);
};
(api as any).delete = function del<T = any>(path: string, init?: RequestInit) {
  return requestJson<T>('DELETE', path, undefined, init);
};

// Optional typed exports for convenience
export const apiGet = (api as any).get as <T = any>(path: string, init?: RequestInit) => Promise<ApiResponse<T>>;
export const apiPost = (api as any).post as <T = any>(path: string, body?: any, init?: RequestInit) => Promise<ApiResponse<T>>;
export const apiPatch = (api as any).patch as <T = any>(path: string, body?: any, init?: RequestInit) => Promise<ApiResponse<T>>;
export const apiDelete = (api as any).delete as <T = any>(path: string, init?: RequestInit) => Promise<ApiResponse<T>>;
TS

echo "OK: lib/api.ts rewritten (hybrid api + token helpers)"

echo
echo "==> Build dashboard to verify"
cd "$ROOT/apps/dashboard"
pnpm -s build

echo
echo "DONE."
echo "Root build:"
echo "  cd $ROOT && pnpm -s build"
