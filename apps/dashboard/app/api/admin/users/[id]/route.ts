import { NextRequest } from 'next/server';
import { proxyToApi } from '@/lib/proxy';

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  return proxyToApi(req, `/admin/users/${id}`);
}
