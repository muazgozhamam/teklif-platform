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

const API_ROOT = '/api/admin/commission';

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
      const res = await api.get<OverviewPayload>(`${API_ROOT}/overview`);
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
      await api.post(`${API_ROOT}/snapshots`, { dealId: dealId.trim() });
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
      subtitle="Hakediş süreçlerini tek ekranda izleyin ve yönetin."
      nav={[]}
    >
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <Card><CardDescription>Toplam Hakediş</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.totalEarnedMinor)}</CardTitle></Card>
        <Card><CardDescription>Toplam Ödenen</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.totalPaidMinor)}</CardTitle></Card>
        <Card><CardDescription>Toplam Ters Kayıt</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.totalReversedMinor)}</CardTitle></Card>
        <Card><CardDescription>Kalan Ödeme</CardDescription><CardTitle className="mt-1">{loading ? '…' : formatMinorTry(overview?.payableOutstandingMinor)}</CardTitle></Card>
        <Card><CardDescription>Bekleyen Onay</CardDescription><CardTitle className="mt-1">{loading ? '…' : String(overview?.pendingApprovalCount || 0)}</CardTitle></Card>
      </div>

      <Card className="mt-4">
        <CardTitle>İşlemden Hakediş Kaydı Oluştur</CardTitle>
        <CardDescription>İşlem kapandıysa bu kayıtla hakediş dağıtımını başlatırsınız.</CardDescription>
        <div className="mt-3 flex flex-col gap-2 md:flex-row">
          <Input value={dealId} onChange={(e) => setDealId(e.target.value)} placeholder="İşlem ID" className="md:max-w-xl" />
          <Button onClick={createSnapshot} disabled={saving || !dealId.trim()}>
            {saving ? 'Oluşturuluyor…' : 'Hakediş Kaydı Oluştur'}
          </Button>
        </div>
      </Card>

      <div className="mt-4 grid gap-3 md:grid-cols-3">
        <Link href="/admin/commission/pending" className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <div className="text-sm font-medium">Onay Kuyruğu</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Onay bekleyen hakediş kayıtlarını yönet.</div>
        </Link>
        <Link href="/admin/commission/payouts" className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <div className="text-sm font-medium">Ödeme Kayıtları</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Onaylanan hakedişler için ödeme girin.</div>
        </Link>
        <Link href="/admin/commission/disputes" className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <div className="text-sm font-medium">Uyuşmazlıklar</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Açılan anlaşmazlık kayıtlarını takip edin.</div>
        </Link>
        <Link href="/admin/commission/period-locks" className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <div className="text-sm font-medium">Dönem Kilidi</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Belirli dönemlerde işlemleri geçici olarak kilitleyin.</div>
        </Link>
      </div>
    </RoleShell>
  );
}
