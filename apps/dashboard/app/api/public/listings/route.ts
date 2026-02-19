import { proxyToApi } from '@/lib/proxy';

export async function GET(req: Request) {
  const url = new URL(req.url);
  const search = url.search || '';
  return proxyToApi(req, `/public/listings${search}`);
}

