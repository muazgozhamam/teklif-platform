import { NextRequest } from 'next/server';
import { proxyToApi } from '@/lib/proxy';

export async function GET(req: NextRequest) {
  const q = req.nextUrl.search || '';
  return proxyToApi(req, `/admin/users${q}`);
}

export async function POST(req: NextRequest) {
  return proxyToApi(req, '/admin/users');
}
