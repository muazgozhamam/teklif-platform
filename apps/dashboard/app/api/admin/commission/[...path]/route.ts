import { proxyToApi } from '@/lib/proxy';

type Ctx = { params: Promise<{ path: string[] }> };

export async function GET(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  return proxyToApi(req, `/admin/commission/${(path || []).join('/')}`);
}

export async function POST(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  return proxyToApi(req, `/admin/commission/${(path || []).join('/')}`);
}

export async function PUT(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  return proxyToApi(req, `/admin/commission/${(path || []).join('/')}`);
}

export async function PATCH(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  return proxyToApi(req, `/admin/commission/${(path || []).join('/')}`);
}

export async function DELETE(req: Request, ctx: Ctx) {
  const { path } = await ctx.params;
  return proxyToApi(req, `/admin/commission/${(path || []).join('/')}`);
}
