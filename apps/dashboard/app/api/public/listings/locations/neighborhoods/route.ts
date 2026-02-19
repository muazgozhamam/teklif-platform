import { proxyToApi } from '@/lib/proxy';

export async function GET(req: Request) {
  return proxyToApi(req, '/public/listings/locations/neighborhoods');
}
