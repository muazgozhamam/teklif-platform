import { proxyToApi } from '@/lib/proxy';

export async function GET(req: Request) {
  const { search } = new URL(req.url);
  return proxyToApi(req, `/admin/leaderboards${search}`);
}
