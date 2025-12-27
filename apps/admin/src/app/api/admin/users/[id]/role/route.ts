export const dynamic = 'force-dynamic';

const API_BASE = process.env.API_BASE_URL || 'http://localhost:3001';

export async function PATCH(req: Request, ctx: { params: { id: string } }) {
  const body = await req.text();
  const r = await fetch(`${API_BASE}/admin/users/${ctx.params.id}/role`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body,
    cache: 'no-store',
  });
  const t = await r.text();
  return new Response(t, { status: r.status, headers: { 'Content-Type': r.headers.get('content-type') || 'application/json' }});
}
