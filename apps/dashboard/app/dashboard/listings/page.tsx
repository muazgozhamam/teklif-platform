'use client';

import React from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { requireAuth } from '@/lib/auth';
import { Button } from '@/src/ui/components/Button';
import { Input } from '@/src/ui/components/Input';
import { Card } from '@/src/ui/components/Card';

type Listing = {
  id: string;
  title?: string | null;
  status?: string | null;
  city?: string | null;
  district?: string | null;
  neighborhood?: string | null;
  priceAmount?: string | number | null;
  currency?: string | null;
  lat?: number | null;
  lng?: number | null;
};

export default function DashboardListingsPage() {
  const [allowed, setAllowed] = React.useState(false);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [items, setItems] = React.useState<Listing[]>([]);
  const [q, setQ] = React.useState('');

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<{ items: Listing[] }>('/listings', {
        params: { take: 50, q: q || undefined },
      });
      setItems(Array.isArray(res.data?.items) ? res.data.items : []);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'İlanlar yüklenemedi');
    } finally {
      setLoading(false);
    }
  }, [q]);

  React.useEffect(() => {
    setAllowed(requireAuth());
  }, []);

  React.useEffect(() => {
    if (!allowed) return;
    void load();
  }, [allowed, load]);

  if (!allowed) return null;

  return (
    <main className="min-h-screen bg-[var(--bg)] px-4 py-6 text-[var(--text)] md:px-8">
      <div className="mx-auto w-full max-w-[1100px]">
        <div className="mb-4 flex items-center justify-between gap-3">
          <div>
            <h1 className="text-xl font-semibold">İlan Yönetimi</h1>
            <p className="text-sm text-[var(--muted)]">Kendi ilanlarını oluştur, düzenle, yayına al ve arşivle.</p>
          </div>
          <Link href="/dashboard/listings/new">
            <Button variant="primary">Yeni İlan</Button>
          </Link>
        </div>

        <Card className="mb-4 flex items-center gap-2">
          <Input placeholder="Başlık ara..." value={q} onChange={(e) => setQ(e.target.value)} />
          <Button variant="secondary" onClick={() => void load()} disabled={loading}>
            Ara
          </Button>
        </Card>

        {error ? <div className="mb-3 rounded-lg border border-[var(--danger)]/40 bg-[var(--danger)]/10 px-3 py-2 text-sm">{error}</div> : null}

        <div className="grid gap-3">
          {items.map((row) => (
            <Card key={row.id} className="flex items-center justify-between gap-3">
              <div>
                <div className="font-medium">{row.title || 'İlan'}</div>
                <div className="text-xs text-[var(--muted)]">
                  {[row.city, row.district, row.neighborhood].filter(Boolean).join(' / ') || '-'} • {row.status || '-'} • pin:{' '}
                  {typeof row.lat === 'number' && typeof row.lng === 'number' ? 'var' : 'yok'}
                </div>
              </div>
              <Link href={`/dashboard/listings/${row.id}/edit`}>
                <Button variant="secondary">Düzenle</Button>
              </Link>
            </Card>
          ))}
          {!loading && items.length === 0 ? <Card className="text-sm text-[var(--muted)]">Henüz ilan yok.</Card> : null}
        </div>
      </div>
    </main>
  );
}

