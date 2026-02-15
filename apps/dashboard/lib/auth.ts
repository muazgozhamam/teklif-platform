import { getAccessToken, getSessionRoleFromToken } from './session';
import { roleHomePath } from './roles';

export function requireAuth(): boolean {
  if (typeof window === 'undefined') return true;
  const token = getAccessToken();
  if (!token) {
    window.location.href = '/login';
    return false;
  }
  return true;
}

export function requireRole(allowedRoles: string[]): boolean {
  if (typeof window === 'undefined') return true;
  if (!requireAuth()) return false;

  const role = getSessionRoleFromToken();
  const allowed = new Set(allowedRoles.map((r) => String(r).toUpperCase()));
  if (!allowed.has(role)) {
    window.location.href = roleHomePath(role);
    return false;
  }
  return true;
}
