'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';
import { Button } from '@/src/ui/components/Button';
import { Alert } from '@/src/ui/components/Alert';
import { api } from '@/lib/api';
import { formatMinorTry } from '@/app/_components/commission-utils';

type OverviewPayload = {
  totalEarnedMinor: string;
  totalPaidMinor: string;
  totalReversedMinor: string;
  payableOutstandingMinor: string;
  pendingApprovalCount: number;
};

export default function AdminCommissionOverviewPage() {
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [overview, setOverview] = React.useState<OverviewPayload | null>(null);
  const [dealId, setDealId] = React.useState('');

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<OverviewPayload>('/admin/commission/overview');
      setOverview(res.data);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Hakediş özeti alınamadı.');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    load();
  }, []);

  async function createSnapshot() {
    if (!dealId.trim()) return;
    setSaving(true);
    setError(null);
    try {
      await api.post('/admin/commission/snapshots', { dealId: dealId.trim() });
      setDealId('');
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Snapshot oluşturulamadı.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <RoleShell
      role="ADMIN"
      title="Hakediş Genel Bakış"
      subtitle="Ledger bazlı hakediş özeti ve operasyon kısayolları."
      nav={[]}
    >
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <Card><CardDescription>Toplam Earned</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.totalEarnedMinor)}</CardTitle></Card>
        <Card><CardDescription>Toplam Paid</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.totalPaidMinor)}</CardTitle></Card>
        <Card><CardDescription>Toplam Reversed</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.totalReversedMinor)}</CardTitle></Card>
        <Card><CardDescription>Outstanding</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.payableOutstandingMinor)}</CardTitle></Card>
        <Card><CardDescription>Bekleyen Onay</CardDescription><CardTitle className="mt-1">{loading ? '…' : String(overview?.pendingApprovalCount || 0)}</CardTitle></Card>
      </div>

      <Card className="mt-4">
        <CardTitle>Deal’den Snapshot Oluştur</CardTitle>
        <CardDescription>Deal status = WON olmalı, listing.price dolu olmalı.</CardDescription>
        <div className="mt-3 flex flex-col gap-2 md:flex-row">
          <Input value={dealId} onChange={(e) => setDealId(e.target.value)} placeholder="Deal ID" className="md:max-w-xl" />
          <Button onClick={createSnapshot} disabled={saving || !dealId.trim()}>
            {saving ? 'Oluşturuluyor…' : 'Snapshot Oluştur'}
          </Button>
        </div>
      </Card>

      <div className="mt-4 grid gap-3 md:grid-cols-3">
        <Link href="/admin/commission/pending" className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <div className="text-sm font-medium">Onay Kuyruğu</div>
          <div className="mt-1 text-xs text-[var(--muted)]">PENDING_APPROVAL snapshot’ları yönet.</div>
        </Link>
        <Link href="/admin/commission/payouts" className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <div className="text-sm font-medium">Ödeme Planı</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Onaylı satırlara payout oluştur.</div>
        </Link>
        <Link href="/admin/commission/disputes" className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <div className="text-sm font-medium">Uyuşmazlıklar</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Faz 2 için dispute yönetimi placeholder.</div>
        </Link>
      </div>
    </RoleShell>
  );
}
