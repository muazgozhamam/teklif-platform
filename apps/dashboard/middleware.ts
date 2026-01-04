import { NextRequest, NextResponse } from 'next/server';

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

export function middleware(req: NextRequest) {
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

  // TOKEN VAR → role kontrolü YOK
  return NextResponse.next();
}

export const config = {
  matcher: ['/hunter/:path*', '/broker/:path*', '/consultant/:path*'],
};
