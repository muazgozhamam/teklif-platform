import { NextRequest, NextResponse } from 'next/server';
import { requiredRoleForPath, roleHomePath } from '@/lib/roles';

const TOKEN_COOKIE = 'accessToken';

function isPublicPath(pathname: string) {
  return (
    pathname === '/login' ||
    pathname.startsWith('/public') ||
    pathname.startsWith('/_next') ||
    pathname.startsWith('/favicon') ||
    pathname.startsWith('/assets')
  );
}

function decodeJwtRole(token: string): string {
  try {
    const parts = String(token || '').split('.');
    if (parts.length < 2) return '';
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64.length % 4;
    if (pad) b64 += '='.repeat(4 - pad);
    const json = atob(b64);
    const payload = JSON.parse(json) as { role?: string };
    return String(payload.role || '').toUpperCase();
  } catch {
    return '';
  }
}

export function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  if (isPublicPath(pathname)) {
    return NextResponse.next();
  }

  const token = req.cookies.get(TOKEN_COOKIE)?.value;

  if (!token) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('next', pathname);
    return NextResponse.redirect(url);
  }

  const requiredRole = requiredRoleForPath(pathname);
  if (requiredRole) {
    const actualRole = decodeJwtRole(token);
    if (actualRole !== 'ADMIN' && actualRole !== requiredRole) {
      const url = req.nextUrl.clone();
      url.pathname = roleHomePath(actualRole);
      if (url.pathname === '/login') {
        url.searchParams.set('next', pathname);
      }
      return NextResponse.redirect(url);
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/hunter/:path*', '/broker/:path*', '/consultant/:path*', '/admin/:path*'],
};
