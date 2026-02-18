'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import Link from 'next/link';
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
  currency: string;
  status: string;
  createdAt: string;
  deal?: { city?: string; district?: string; type?: string };
  maker?: { name?: string; email?: string };
};

export default function AdminCommissionPendingPage() {
  const [rows, setRows] = React.useState<PendingRow[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [busyId, setBusyId] = React.useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<PendingRow[]>('/admin/commission/pending-approvals');
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Onay kuyruğu yüklenemedi.');
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
      await api.post(`/admin/commission/snapshots/${snapshotId}/approve`, { note: 'Admin onayı' });
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Onay işlemi başarısız.');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <RoleShell role="ADMIN" title="Hakediş Onay Kuyruğu" subtitle="PENDING_APPROVAL snapshot kayıtları." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <Card>
        <CardTitle>Bekleyen Snapshotlar</CardTitle>
        <CardDescription>Maker-checker kuralı aktif: oluşturan onaylayamaz.</CardDescription>
        {loading ? <div className="mt-3 text-sm text-[var(--muted)]">Yükleniyor…</div> : null}

        {!loading && rows.length === 0 ? <div className="mt-3 text-sm text-[var(--muted)]">Bekleyen kayıt yok.</div> : null}

        {!loading && rows.length > 0 ? (
          <div className="mt-3 overflow-auto">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--border)] text-left text-xs text-[var(--muted)]">
                  <th className="px-3 py-2">Deal</th>
                  <th className="px-3 py-2">Havuz</th>
                  <th className="px-3 py-2">Oluşturan</th>
                  <th className="px-3 py-2">Tarih</th>
                  <th className="px-3 py-2">İşlem</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b border-[var(--border)]">
                    <td className="px-3 py-2">
                      <div className="font-medium">{row.dealId}</div>
                      <div className="text-xs text-[var(--muted)]">{[row.deal?.city, row.deal?.district, row.deal?.type].filter(Boolean).join(' / ') || '-'}</div>
                    </td>
                    <td className="px-3 py-2">{formatMinorTry(row.poolAmountMinor)}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">{row.maker?.name || row.maker?.email || '-'}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">{new Date(row.createdAt).toLocaleString('tr-TR')}</td>
                    <td className="px-3 py-2">
                      <div className="flex flex-wrap gap-2">
                        <Button className="h-8 px-3 text-xs" onClick={() => approve(row.id)} disabled={busyId === row.id}>
                          {busyId === row.id ? 'Onaylanıyor…' : 'Onayla'}
                        </Button>
                        <Link href={`/admin/commission/deals/${row.dealId}`} className="ui-interactive inline-flex h-8 items-center rounded-xl border border-[var(--border)] px-3 text-xs hover:bg-[var(--interactive-hover-bg)]">
                          Detay
                        </Link>
                      </div>
                    </td>
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
