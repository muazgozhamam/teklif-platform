export type AppRole = 'HUNTER' | 'CONSULTANT' | 'BROKER' | 'ADMIN';

export function normalizeRole(role?: string | null): string {
  return String(role || '').trim().toUpperCase();
}

export function requiredRoleForPath(pathname: string): AppRole | null {
  if (pathname.startsWith('/hunter')) return 'HUNTER';
  if (pathname.startsWith('/consultant')) return 'CONSULTANT';
  if (pathname.startsWith('/broker')) return 'BROKER';
  if (pathname.startsWith('/admin')) return 'ADMIN';
  return null;
}

export function roleHomePath(role?: string | null): string {
  const r = normalizeRole(role);
  if (r === 'HUNTER') return '/hunter';
  if (r === 'CONSULTANT') return '/consultant';
  if (r === 'BROKER') return '/broker';
  if (r === 'ADMIN') return '/admin';
  return '/login';
}

export function roleLabelTr(role?: string | null): string {
  const r = normalizeRole(role);
  if (r === 'ADMIN') return 'Yönetici';
  if (r === 'BROKER') return 'Broker';
  if (r === 'CONSULTANT') return 'Danışman';
  if (r === 'HUNTER') return 'İş Ortağı';
  return 'Kullanıcı';
}
