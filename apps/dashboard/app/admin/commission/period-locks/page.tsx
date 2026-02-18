'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Alert } from '@/src/ui/components/Alert';
import { Input } from '@/src/ui/components/Input';
import { Button } from '@/src/ui/components/Button';
import { api } from '@/lib/api';

type LockRow = {
  id: string;
  periodFrom: string;
  periodTo: string;
  reason: string;
  isActive: boolean;
  createdAt: string;
  unlockedAt?: string | null;
  creator?: { name?: string; email?: string };
  unlocker?: { name?: string; email?: string };
};

export default function CommissionPeriodLocksPage() {
  const [rows, setRows] = React.useState<LockRow[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [ok, setOk] = React.useState<string | null>(null);

  const [periodFrom, setPeriodFrom] = React.useState('');
  const [periodTo, setPeriodTo] = React.useState('');
  const [reason, setReason] = React.useState('Aylık kapanış dönemi');

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<LockRow[]>('/admin/commission/period-locks');
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Period lock listesi alınamadı.');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    load();
  }, []);

  async function createLock(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setOk(null);
    try {
      await api.post('/admin/commission/period-locks', {
        periodFrom,
        periodTo,
        reason,
      });
      setOk('Period lock oluşturuldu.');
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Period lock oluşturulamadı.');
    } finally {
      setSaving(false);
    }
  }

  async function releaseLock(lockId: string) {
    setError(null);
    setOk(null);
    try {
      await api.post(`/admin/commission/period-locks/${lockId}/release`, { reason: 'Manuel açma' });
      setOk('Period lock serbest bırakıldı.');
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Period lock açılamadı.');
    }
  }

  async function escalateOverdue() {
    setError(null);
    setOk(null);
    try {
      const res = await api.post<{ escalated: number }>('/admin/commission/disputes/escalate-overdue', {});
      setOk(`Escalation tamamlandı: ${res.data?.escalated ?? 0} kayıt`);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'SLA escalation çalıştırılamadı.');
    }
  }

  return (
    <RoleShell role="ADMIN" title="Hakediş Dönem Kilidi" subtitle="Period lock ve dispute SLA escalation yönetimi." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}
      {ok ? <Alert type="success" message={ok} className="mb-4" /> : null}

      <Card>
        <CardTitle>Yeni Period Lock</CardTitle>
        <CardDescription>Aktif kilit dönemlerinde approve/payout/reverse işlemleri engellenir.</CardDescription>
        <form className="mt-3 grid gap-3 md:grid-cols-4" onSubmit={createLock}>
          <Input type="datetime-local" value={periodFrom} onChange={(e) => setPeriodFrom(e.target.value)} required />
          <Input type="datetime-local" value={periodTo} onChange={(e) => setPeriodTo(e.target.value)} required />
          <Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Kilitleme nedeni" required />
          <Button type="submit" disabled={saving}>{saving ? 'Oluşturuluyor…' : 'Lock Oluştur'}</Button>
        </form>
        <div className="mt-3">
          <Button variant="secondary" onClick={escalateOverdue}>Overdue Dispute Escalate Çalıştır</Button>
        </div>
      </Card>

      <Card className="mt-4">
        <CardTitle>Period Lock Listesi</CardTitle>
        {loading ? <div className="mt-3 text-sm text-[var(--muted)]">Yükleniyor…</div> : null}
        {!loading && rows.length === 0 ? <div className="mt-3 text-sm text-[var(--muted)]">Kayıt yok.</div> : null}
        {!loading && rows.length > 0 ? (
          <div className="mt-3 overflow-auto">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--border)] text-left text-xs text-[var(--muted)]">
                  <th className="px-3 py-2">Durum</th>
                  <th className="px-3 py-2">Dönem</th>
                  <th className="px-3 py-2">Neden</th>
                  <th className="px-3 py-2">Açan</th>
                  <th className="px-3 py-2">İşlem</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b border-[var(--border)]">
                    <td className="px-3 py-2">{row.isActive ? 'ACTIVE' : 'RELEASED'}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">
                      {new Date(row.periodFrom).toLocaleString('tr-TR')}<br />{new Date(row.periodTo).toLocaleString('tr-TR')}
                    </td>
                    <td className="px-3 py-2">{row.reason}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">{row.creator?.name || row.creator?.email || '-'}</td>
                    <td className="px-3 py-2">
                      {row.isActive ? (
                        <Button className="h-8 px-3 text-xs" onClick={() => releaseLock(row.id)}>Release</Button>
                      ) : (
                        <span className="text-xs text-[var(--muted)]">{row.unlocker?.name || row.unlocker?.email || '-'}</span>
                      )}
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
