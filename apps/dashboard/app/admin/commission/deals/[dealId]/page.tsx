'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import { useParams } from 'next/navigation';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Button } from '@/src/ui/components/Button';
import { Alert } from '@/src/ui/components/Alert';
import { api } from '@/lib/api';
import { formatMinorTry } from '@/app/_components/commission-utils';

const API_ROOT = '/api/admin/commission';

type Payload = {
  snapshots: Array<{
    id: string;
    dealId: string;
    status: string;
    version: number;
    createdAt: string;
    approvedAt?: string;
    poolAmountMinor: string;
    allocations: Array<{
      id: string;
      role: string;
      status: string;
      amountMinor: string;
      user?: { name?: string; email?: string };
    }>;
  }>;
  ledger: Array<{
    id: string;
    entryType: string;
    direction: string;
    amountMinor: string;
    occurredAt: string;
    memo?: string;
  }>;
  payoutLinks: Array<{
    id: string;
    amountMinor: string;
    allocationId: string;
    payout: { id: string; paidAt: string; method: string; referenceNo?: string };
  }>;
};

export default function AdminCommissionDealDetailPage() {
  const params = useParams<{ dealId: string }>();
  const dealId = String(params?.dealId || '');
  const [data, setData] = React.useState<Payload | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<Payload>(`${API_ROOT}/deals/${dealId}`);
      setData(res.data);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'İşlem hakediş detayı alınamadı.');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dealId]);

  async function reverse(snapshotId: string) {
    setError(null);
    const reasonInput = window.prompt('Ters kayıt nedeni', 'Yönetici düzeltmesi');
    if (!reasonInput) return;
    const amountInput = window.prompt('Kısmi işlem için kuruş tutarı (boş bırak = tamamı)', '');
    try {
      await api.post(`${API_ROOT}/snapshots/${snapshotId}/reverse`, {
        reason: reasonInput,
        amountMinor: amountInput && amountInput.trim() ? amountInput.trim() : undefined,
      });
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Ters kayıt işlemi başarısız.');
    }
  }

  return (
    <RoleShell role="ADMIN" title="İşlem Hakediş Detayı" subtitle={dealId} nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}
      {loading ? <Card><CardDescription>Yükleniyor…</CardDescription></Card> : null}

      {!loading && !data ? <Card><CardDescription>Kayıt bulunamadı.</CardDescription></Card> : null}

      {!loading && data ? (
        <div className="space-y-4">
          <Card>
            <CardTitle>Hakediş Kayıtları</CardTitle>
            <div className="mt-3 space-y-3">
              {data.snapshots.length === 0 ? <div className="text-sm text-[var(--muted)]">Kayıt yok.</div> : null}
              {data.snapshots.map((s) => (
                <div key={s.id} className="rounded-xl border border-[var(--border)] p-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div>
                      <div className="text-sm font-medium">v{s.version} • {s.status}</div>
                      <div className="text-xs text-[var(--muted)]">Havuz: {formatMinorTry(s.poolAmountMinor)}</div>
                    </div>
                    <Button variant="danger" className="h-8 px-3 text-xs" onClick={() => reverse(s.id)}>
                      Kısmi/Tam Ters Kayıt
                    </Button>
                  </div>
                  <div className="mt-2 overflow-auto">
                    <table className="min-w-full text-sm">
                      <thead><tr className="text-left text-xs text-[var(--muted)]"><th className="px-2 py-1">Rol</th><th className="px-2 py-1">Kullanıcı</th><th className="px-2 py-1">Durum</th><th className="px-2 py-1">Tutar</th></tr></thead>
                      <tbody>
                        {s.allocations.map((a) => (
                          <tr key={a.id} className="border-t border-[var(--border)]">
                            <td className="px-2 py-1">{a.role}</td>
                            <td className="px-2 py-1 text-xs text-[var(--muted)]">{a.user?.name || a.user?.email || '-'}</td>
                            <td className="px-2 py-1">{a.status}</td>
                            <td className="px-2 py-1">{formatMinorTry(a.amountMinor)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              ))}
            </div>
          </Card>

          <Card>
            <CardTitle>Ledger</CardTitle>
            <div className="mt-3 overflow-auto">
              <table className="min-w-full text-sm">
                <thead><tr className="text-left text-xs text-[var(--muted)]"><th className="px-2 py-1">Zaman</th><th className="px-2 py-1">Tip</th><th className="px-2 py-1">Yön</th><th className="px-2 py-1">Tutar</th><th className="px-2 py-1">Not</th></tr></thead>
                <tbody>
                  {data.ledger.map((l) => (
                    <tr key={l.id} className="border-t border-[var(--border)]">
                      <td className="px-2 py-1 text-xs text-[var(--muted)]">{new Date(l.occurredAt).toLocaleString('tr-TR')}</td>
                      <td className="px-2 py-1">{l.entryType}</td>
                      <td className="px-2 py-1">{l.direction}</td>
                      <td className="px-2 py-1">{formatMinorTry(l.amountMinor)}</td>
                      <td className="px-2 py-1 text-xs text-[var(--muted)]">{l.memo || '-'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      ) : null}
    </RoleShell>
  );
}
