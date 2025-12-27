import { NextResponse } from 'next/server';

function getApiBase() {
  return process.env.API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001';
}

export async function POST(req: Request) {
  const apiBase = getApiBase();
  const body = await req.text();

  const upstream = await fetch(`${apiBase}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
    cache: 'no-store',
  });

  const text = await upstream.text();
  let data: any = null;
  try { data = JSON.parse(text); } catch {}

  // token alanını yakala
  const token =
    data?.access_token ||
    data?.token ||
    data?.jwt ||
    (typeof data === 'string' ? data : null);

  // upstream hata ise aynen dön
  if (!upstream.ok) {
    return new NextResponse(text, {
      status: upstream.status,
      headers: { 'Content-Type': upstream.headers.get('content-type') || 'application/json' },
    });
  }

  const res = new NextResponse(text, {
    status: upstream.status,
    headers: { 'Content-Type': upstream.headers.get('content-type') || 'application/json' },
  });

  if (token) {
    // 3002 origin'e HttpOnly cookie yaz
    res.headers.append(
      'Set-Cookie',
      `access_token=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax`
    );
  }

  return res;
}
