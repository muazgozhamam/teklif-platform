export const dynamic = 'force-dynamic';

const API_BASE = process.env.API_BASE_URL || 'http://localhost:3001';

export async function GET() {
  const r = await fetch(`${API_BASE}/admin/users`, { cache: 'no-store' });
  const t = await r.text();
  return new Response(t, { status: r.status, headers: { 'Content-Type': r.headers.get('content-type') || 'application/json' }});
}
