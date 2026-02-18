'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Alert } from '@/src/ui/components/Alert';
import { Button } from '@/src/ui/components/Button';
import { api } from '@/lib/api';

type DisputeRow = {
  id: string;
  dealId: string;
  snapshotId?: string | null;
  type: string;
  status: string;
  slaDueAt: string;
  createdAt: string;
  resolutionNote?: string | null;
  opener?: { name?: string; email?: string };
  againstUser?: { name?: string; email?: string };
};

export default function AdminCommissionDisputesPage() {
  const [rows, setRows] = React.useState<DisputeRow[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [busyId, setBusyId] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  const [dealId, setDealId] = React.useState('');
  const [snapshotId, setSnapshotId] = React.useState('');
  const [againstUserId, setAgainstUserId] = React.useState('');
  const [type, setType] = React.useState<'ATTRIBUTION' | 'AMOUNT' | 'ROLE' | 'OTHER'>('OTHER');
  const [note, setNote] = React.useState('');

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<DisputeRow[]>('/admin/commission/disputes');
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Dispute listesi alınamadı.');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    load();
  }, []);

  async function createDispute(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    try {
      await api.post('/admin/commission/disputes', {
        dealId: dealId.trim(),
        snapshotId: snapshotId.trim() || undefined,
        againstUserId: againstUserId.trim() || undefined,
        type,
        note: note.trim() || undefined,
      });
      setDealId('');
      setSnapshotId('');
      setAgainstUserId('');
      setNote('');
      setType('OTHER');
      await load();
    } catch (err: any) {
      setError(err?.data?.message || err?.message || 'Dispute oluşturulamadı.');
    }
  }

  async function setStatus(disputeId: string, status: 'UNDER_REVIEW' | 'ESCALATED' | 'RESOLVED_APPROVED' | 'RESOLVED_REJECTED') {
    setBusyId(disputeId);
    setError(null);
    try {
      await api.post(`/admin/commission/disputes/${disputeId}/status`, { status, note: `Status -> ${status}` });
      await load();
    } catch (err: any) {
      setError(err?.data?.message || err?.message || 'Dispute status güncellenemedi.');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <RoleShell role="ADMIN" title="Hakediş Uyuşmazlıkları" subtitle="Faz 2 dispute lifecycle aktif." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <Card>
        <CardTitle>Yeni Dispute</CardTitle>
        <CardDescription>Deal bazında uyuşmazlık açıp SLA takibini başlat.</CardDescription>
        <form className="mt-3 grid gap-3 md:grid-cols-2" onSubmit={createDispute}>
          <input className="rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm" value={dealId} onChange={(e) => setDealId(e.target.value)} placeholder="dealId (zorunlu)" required />
          <input className="rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm" value={snapshotId} onChange={(e) => setSnapshotId(e.target.value)} placeholder="snapshotId (opsiyonel)" />
          <input className="rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm" value={againstUserId} onChange={(e) => setAgainstUserId(e.target.value)} placeholder="againstUserId (opsiyonel)" />
          <select className="rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm" value={type} onChange={(e) => setType(e.target.value as any)}>
            <option value="OTHER">OTHER</option>
            <option value="ATTRIBUTION">ATTRIBUTION</option>
            <option value="AMOUNT">AMOUNT</option>
            <option value="ROLE">ROLE</option>
          </select>
          <input className="rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm md:col-span-2" value={note} onChange={(e) => setNote(e.target.value)} placeholder="Not (opsiyonel)" />
          <div className="md:col-span-2">
            <Button type="submit" className="h-9 px-4 text-sm">Dispute Aç</Button>
          </div>
        </form>
      </Card>

      <Card>
        <CardTitle>Açık Kayıtlar</CardTitle>
        {loading ? <div className="mt-3 text-sm text-[var(--muted)]">Yükleniyor…</div> : null}
        {!loading && rows.length === 0 ? <div className="mt-3 text-sm text-[var(--muted)]">Dispute kaydı yok.</div> : null}
        {!loading && rows.length > 0 ? (
          <div className="mt-3 overflow-auto">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--border)] text-left text-xs text-[var(--muted)]">
                  <th className="px-3 py-2">Deal</th>
                  <th className="px-3 py-2">Tip</th>
                  <th className="px-3 py-2">Durum</th>
                  <th className="px-3 py-2">SLA</th>
                  <th className="px-3 py-2">Açan</th>
                  <th className="px-3 py-2">Hedef</th>
                  <th className="px-3 py-2">İşlem</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b border-[var(--border)] align-top">
                    <td className="px-3 py-2">
                      <div className="font-medium">{row.dealId}</div>
                      <div className="text-xs text-[var(--muted)]">{row.snapshotId || '-'}</div>
                    </td>
                    <td className="px-3 py-2">{row.type}</td>
                    <td className="px-3 py-2">{row.status}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">{new Date(row.slaDueAt).toLocaleString('tr-TR')}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">{row.opener?.name || row.opener?.email || '-'}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">{row.againstUser?.name || row.againstUser?.email || '-'}</td>
                    <td className="px-3 py-2">
                      <div className="flex flex-wrap gap-2">
                        <Button className="h-8 px-3 text-xs" onClick={() => setStatus(row.id, 'UNDER_REVIEW')} disabled={busyId === row.id}>İncelemede</Button>
                        <Button variant="secondary" className="h-8 px-3 text-xs" onClick={() => setStatus(row.id, 'ESCALATED')} disabled={busyId === row.id}>Escalate</Button>
                        <Button variant="primary" className="h-8 px-3 text-xs" onClick={() => setStatus(row.id, 'RESOLVED_APPROVED')} disabled={busyId === row.id}>Kabul</Button>
                        <Button variant="danger" className="h-8 px-3 text-xs" onClick={() => setStatus(row.id, 'RESOLVED_REJECTED')} disabled={busyId === row.id}>Red</Button>
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
