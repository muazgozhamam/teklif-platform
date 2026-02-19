import { proxyToApi } from '@/lib/proxy';

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, ctx: Ctx) {
  const { id } = await ctx.params;
  return proxyToApi(req, `/public/listings/${id}`);
}

