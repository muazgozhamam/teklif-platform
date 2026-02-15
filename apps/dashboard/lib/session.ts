import { normalizeRole } from './roles';

const ACCESS_TOKEN_KEY = 'accessToken';
const USER_ID_KEY = 'x-user-id';

export function getAccessToken(): string {
  if (typeof window === 'undefined') return '';
  return String(window.localStorage.getItem(ACCESS_TOKEN_KEY) || '').trim();
}

export function getUserId(): string {
  if (typeof window === 'undefined') return '';
  return String(window.localStorage.getItem(USER_ID_KEY) || '').trim();
}

export function clearSession() {
  if (typeof window === 'undefined') return;
  window.localStorage.removeItem(ACCESS_TOKEN_KEY);
  window.localStorage.removeItem(USER_ID_KEY);
  document.cookie = 'accessToken=; Path=/; Max-Age=0; SameSite=Lax';
}

export function decodeJwtPayload(token: string): { sub?: string; role?: string } {
  try {
    const parts = String(token || '').split('.');
    if (parts.length < 2) return {};
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64.length % 4;
    if (pad) b64 += '='.repeat(4 - pad);
    const json = typeof window !== 'undefined' ? window.atob(b64) : Buffer.from(b64, 'base64').toString('utf8');
    const payload = JSON.parse(json) as { sub?: string; role?: string };
    return payload || {};
  } catch {
    return {};
  }
}

export function getSessionRoleFromToken(): string {
  const token = getAccessToken();
  return normalizeRole(decodeJwtPayload(token).role);
}
