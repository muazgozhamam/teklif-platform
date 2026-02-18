'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Button } from '@/src/ui/components/Button';
import { Alert } from '@/src/ui/components/Alert';
import { api } from '@/lib/api';
import { formatMinorTry } from '@/app/_components/commission-utils';

type PendingRow = {
  id: string;
  dealId: string;
  poolAmountMinor: string;
  createdAt: string;
  maker?: { name?: string; email?: string };
};

export default function BrokerCommissionApprovalPage() {
  const [rows, setRows] = React.useState<PendingRow[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [busyId, setBusyId] = React.useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<PendingRow[]>('/broker/commission/pending-approvals');
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Kayıtlar yüklenemedi.');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    load();
  }, []);

  async function approve(snapshotId: string) {
    setBusyId(snapshotId);
    setError(null);
    try {
      await api.post(`/broker/commission/snapshots/${snapshotId}/approve`, { note: 'Broker onayı' });
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Onay işlemi başarısız.');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <RoleShell role="BROKER" title="Hakediş Onay Ekranı" subtitle="Broker tarafı bekleyen snapshot onay listesi." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <Card>
        <CardTitle>Bekleyen Onaylar</CardTitle>
        <CardDescription>Maker-checker kuralı broker için de uygulanır.</CardDescription>

        {loading ? <div className="mt-3 text-sm text-[var(--muted)]">Yükleniyor…</div> : null}
        {!loading && rows.length === 0 ? <div className="mt-3 text-sm text-[var(--muted)]">Bekleyen kayıt yok.</div> : null}

        {!loading && rows.length > 0 ? (
          <div className="mt-3 space-y-2">
            {rows.map((row) => (
              <div key={row.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-[var(--border)] px-3 py-2">
                <div>
                  <div className="text-sm font-medium">{row.dealId}</div>
                  <div className="text-xs text-[var(--muted)]">{formatMinorTry(row.poolAmountMinor)} • {row.maker?.name || row.maker?.email || '-'}</div>
                </div>
                <Button className="h-8 px-3 text-xs" onClick={() => approve(row.id)} disabled={busyId === row.id}>
                  {busyId === row.id ? 'Onaylanıyor…' : 'Onayla'}
                </Button>
              </div>
            ))}
          </div>
        ) : null}
      </Card>
    </RoleShell>
  );
}
