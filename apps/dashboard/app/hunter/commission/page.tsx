'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Alert } from '@/src/ui/components/Alert';
import { api } from '@/lib/api';
import { formatMinorTry } from '@/app/_components/commission-utils';

type Payload = {
  earnedMinor: string;
  paidMinor: string;
  outstandingMinor: string;
  items: Array<{
    allocationId: string;
    dealId: string;
    snapshotStatus: string;
    status: string;
    amountMinor: string;
    paidMinor: string;
    outstandingMinor: string;
    createdAt: string;
  }>;
};

export default function HunterCommissionPage() {
  const [data, setData] = React.useState<Payload | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await api.get<Payload>('/hunter/commission/my');
        setData(res.data);
      } catch (e: any) {
        setError(e?.data?.message || e?.message || 'Hakediş verisi alınamadı.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  return (
    <RoleShell role="HUNTER" title="Hakedişim" subtitle="İş ortağı bazlı earned/paid/outstanding görünümü." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <Card><CardDescription>Earned</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(data?.earnedMinor)}</CardTitle></Card>
        <Card><CardDescription>Paid</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(data?.paidMinor)}</CardTitle></Card>
        <Card><CardDescription>Outstanding</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(data?.outstandingMinor)}</CardTitle></Card>
      </div>

      <Card className="mt-4">
        <CardTitle>Kayıtlar</CardTitle>
        {loading ? <div className="mt-3 text-sm text-[var(--muted)]">Yükleniyor…</div> : null}
        {!loading && (data?.items || []).length === 0 ? <div className="mt-3 text-sm text-[var(--muted)]">Kayıt bulunamadı.</div> : null}
        {!loading && (data?.items || []).length > 0 ? (
          <div className="mt-3 overflow-auto">
            <table className="min-w-full text-sm">
              <thead><tr className="text-left text-xs text-[var(--muted)]"><th className="px-2 py-1">Deal</th><th className="px-2 py-1">Durum</th><th className="px-2 py-1">Earned</th><th className="px-2 py-1">Paid</th><th className="px-2 py-1">Kalan</th></tr></thead>
              <tbody>
                {(data?.items || []).map((item) => (
                  <tr key={item.allocationId} className="border-t border-[var(--border)]">
                    <td className="px-2 py-1">{item.dealId}</td>
                    <td className="px-2 py-1 text-xs text-[var(--muted)]">{item.status}</td>
                    <td className="px-2 py-1">{formatMinorTry(item.amountMinor)}</td>
                    <td className="px-2 py-1">{formatMinorTry(item.paidMinor)}</td>
                    <td className="px-2 py-1">{formatMinorTry(item.outstandingMinor)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </Card>
    </RoleShell>
  );
}
