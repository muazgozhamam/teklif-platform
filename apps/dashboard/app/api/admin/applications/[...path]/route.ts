import { proxyToApi } from '@/lib/proxy';

type Ctx = { params: Promise<{ path: string[] }> };

function resolvePath(path: string[]) {
  const joined = (path || []).join('/');
  return joined ? `/admin/applications/${joined}` : '/admin/applications';
}

export async function GET(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  const { search } = new URL(req.url);
  return proxyToApi(req, `${resolvePath(path)}${search}`);
}

export async function POST(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  return proxyToApi(req, resolvePath(path));
}

export async function PATCH(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  return proxyToApi(req, resolvePath(path));
}
