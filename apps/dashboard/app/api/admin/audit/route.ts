import { NextRequest } from 'next/server';
import { proxyToApi } from '@/lib/proxy';

export async function GET(req: NextRequest) {
  const { search } = new URL(req.url);
  return proxyToApi(req, `/admin/audit${search}`);
}
