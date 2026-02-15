import { NextRequest } from 'next/server';
import { proxyToApi } from '@/lib/proxy';

export async function GET(req: NextRequest) {
  return proxyToApi(req, '/admin/commission-config');
}

export async function PATCH(req: NextRequest) {
  return proxyToApi(req, '/admin/commission-config');
}
