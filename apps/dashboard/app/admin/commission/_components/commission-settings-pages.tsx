'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { Alert } from '@/src/ui/components/Alert';
import { Button } from '@/src/ui/components/Button';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';
import { api } from '@/lib/api';

const API_ROOT = '/api/admin/commission';

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

type Policy = {
  id: string;
  name: string;
  calcMethod: 'PERCENTAGE' | 'FIXED';
  commissionRateBasisPoints: number | null;
  fixedCommissionMinor: string | number | null;
  hunterPercentBasisPoints: number;
  consultantPercentBasisPoints: number;
  brokerPercentBasisPoints: number;
  systemPercentBasisPoints: number;
  effectiveFrom: string;
};

type FormState = {
  name: string;
  commissionRatePercent: string;
  hunterPercent: string;
  consultantPercent: string;
  brokerPercent: string;
  systemPercent: string;
};

function bpToPercentString(bp: number | null | undefined) {
  if (bp === null || bp === undefined) return '0';
  return (bp / 100).toFixed(2).replace(/\.00$/, '');
}

function parsePercentToBp(value: string) {
  const normalized = value.replace(',', '.').trim();
  const num = Number(normalized);
  if (!Number.isFinite(num)) return NaN;
  return Math.round(num * 100);
}

function toErrorMessage(error: unknown, fallback: string) {
  if (error && typeof error === 'object') {
    const candidate = error as { data?: { message?: string }; message?: string };
    return candidate.data?.message || candidate.message || fallback;
  }
  return fallback;
}

export function CommissionPeriodLocksPage() {
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
      const res = await api.get<LockRow[]>(`${API_ROOT}/period-locks`);
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Dönem kilidi listesi alınamadı.');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    void load();
  }, []);

  async function createLock(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setOk(null);
    try {
      await api.post(`${API_ROOT}/period-locks`, {
        periodFrom,
        periodTo,
        reason,
      });
      setOk('Dönem kilidi oluşturuldu.');
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Dönem kilidi oluşturulamadı.');
    } finally {
      setSaving(false);
    }
  }

  async function releaseLock(lockId: string) {
    setError(null);
    setOk(null);
    try {
      await api.post(`${API_ROOT}/period-locks/${lockId}/release`, { reason: 'Manuel açma' });
      setOk('Dönem kilidi kaldırıldı.');
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Dönem kilidi kaldırılamadı.');
    }
  }

  async function escalateOverdue() {
    setError(null);
    setOk(null);
    try {
      const res = await api.post<{ escalated: number }>(`${API_ROOT}/disputes/escalate-overdue`, {});
      setOk(`Üst seviyeye taşınan kayıt: ${res.data?.escalated ?? 0}`);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Süre aşımı işlemi çalıştırılamadı.');
    }
  }

  return (
    <RoleShell role="ADMIN" title="Hakediş Dönem Kilidi" subtitle="Belirli dönemlerde hakediş işlemlerini geçici olarak durdurabilirsiniz." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}
      {ok ? <Alert type="success" message={ok} className="mb-4" /> : null}

      <div className="mb-3 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">Kilit Yönetimi</div>
      <Card>
        <CardTitle>Yeni Dönem Kilidi</CardTitle>
        <CardDescription>Kilit aktifken onay, ödeme ve ters kayıt işlemleri durdurulur.</CardDescription>
        <form className="mt-3 grid gap-3 md:grid-cols-4" onSubmit={createLock}>
          <Input type="datetime-local" value={periodFrom} onChange={(e) => setPeriodFrom(e.target.value)} required />
          <Input type="datetime-local" value={periodTo} onChange={(e) => setPeriodTo(e.target.value)} required />
          <Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Kilitleme nedeni" required />
          <Button type="submit" disabled={saving}>{saving ? 'Oluşturuluyor…' : 'Dönemi Kilitle'}</Button>
        </form>
      </Card>

      <Card className="mt-4">
        <CardTitle>Süre Aşımı İşlemi</CardTitle>
        <CardDescription>SLA süresi geçen uyuşmazlıkları tek işlemde üst seviyeye taşı.</CardDescription>
        <div className="mt-3">
          <Button variant="secondary" onClick={escalateOverdue}>Süresi Geçenleri Üst Seviyeye Taşı</Button>
        </div>
      </Card>

      <Card className="mt-4">
        <CardTitle>Dönem Kilidi Listesi</CardTitle>
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
                    <td className="px-3 py-2">{row.isActive ? 'AKTİF' : 'KALDIRILDI'}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">
                      {new Date(row.periodFrom).toLocaleString('tr-TR')}<br />{new Date(row.periodTo).toLocaleString('tr-TR')}
                    </td>
                    <td className="px-3 py-2">{row.reason}</td>
                    <td className="px-3 py-2 text-xs text-[var(--muted)]">{row.creator?.name || row.creator?.email || '-'}</td>
                    <td className="px-3 py-2">
                      {row.isActive ? (
                        <Button className="h-8 px-3 text-xs" onClick={() => releaseLock(row.id)}>Kilidi Kaldır</Button>
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

export function CommissionPoliciesPage() {
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [success, setSuccess] = React.useState<string | null>(null);
  const [activePolicy, setActivePolicy] = React.useState<Policy | null>(null);
  const [form, setForm] = React.useState<FormState>({
    name: 'Default Policy',
    commissionRatePercent: '4',
    hunterPercent: '30',
    consultantPercent: '50',
    brokerPercent: '20',
    systemPercent: '0',
  });

  const splitTotalPercent = React.useMemo(() => {
    const hunter = Number(form.hunterPercent.replace(',', '.')) || 0;
    const consultant = Number(form.consultantPercent.replace(',', '.')) || 0;
    const broker = Number(form.brokerPercent.replace(',', '.')) || 0;
    const system = Number(form.systemPercent.replace(',', '.')) || 0;
    return hunter + consultant + broker + system;
  }, [form.hunterPercent, form.consultantPercent, form.brokerPercent, form.systemPercent]);

  const splitIsValid = Math.abs(splitTotalPercent - 100) < 0.0001;

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<Policy | null>('/api/admin/commission/policies');
      const row = res.data;
      setActivePolicy(row);
      if (row) {
        setForm({
          name: row.name || 'Default Policy',
          commissionRatePercent: bpToPercentString(row.commissionRateBasisPoints),
          hunterPercent: bpToPercentString(row.hunterPercentBasisPoints),
          consultantPercent: bpToPercentString(row.consultantPercentBasisPoints),
          brokerPercent: bpToPercentString(row.brokerPercentBasisPoints),
          systemPercent: bpToPercentString(row.systemPercentBasisPoints),
        });
      }
    } catch (e: unknown) {
      setError(toErrorMessage(e, 'Politika verisi alınamadı.'));
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    void load();
  }, [load]);

  function updateField<K extends keyof FormState>(key: K, value: FormState[K]) {
    setSuccess(null);
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function onSave() {
    setError(null);
    setSuccess(null);
    const commissionRateBasisPoints = parsePercentToBp(form.commissionRatePercent);
    const hunterPercentBasisPoints = parsePercentToBp(form.hunterPercent);
    const consultantPercentBasisPoints = parsePercentToBp(form.consultantPercent);
    const brokerPercentBasisPoints = parsePercentToBp(form.brokerPercent);
    const systemPercentBasisPoints = parsePercentToBp(form.systemPercent);

    if (
      !Number.isFinite(commissionRateBasisPoints) ||
      !Number.isFinite(hunterPercentBasisPoints) ||
      !Number.isFinite(consultantPercentBasisPoints) ||
      !Number.isFinite(brokerPercentBasisPoints) ||
      !Number.isFinite(systemPercentBasisPoints)
    ) {
      setError('Lütfen geçerli oran değerleri girin.');
      return;
    }
    if (hunterPercentBasisPoints + consultantPercentBasisPoints + brokerPercentBasisPoints + systemPercentBasisPoints !== 10_000) {
      setError('Dağılım toplamı %100 olmalı.');
      return;
    }

    setSaving(true);
    try {
      await api.post('/api/admin/commission/policies', {
        name: form.name.trim() || 'Default Policy',
        calcMethod: 'PERCENTAGE',
        commissionRateBasisPoints,
        hunterPercentBasisPoints,
        consultantPercentBasisPoints,
        brokerPercentBasisPoints,
        systemPercentBasisPoints,
      });
      setSuccess('Komisyon politikası güncellendi.');
      await load();
    } catch (e: unknown) {
      setError(toErrorMessage(e, 'Politika kaydedilemedi.'));
    } finally {
      setSaving(false);
    }
  }

  return (
    <RoleShell role="ADMIN" title="Komisyon Politikaları" subtitle="Komisyon oranlarını ve dağıtım paylarını buradan yönetirsiniz." nav={[]}>
      <div className="mb-3 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">Politika Ayarları</div>
      <div className="grid gap-3 md:grid-cols-2">
        <Card>
          <CardTitle>Komisyon Oranı</CardTitle>
          <CardDescription className="mt-1">Toplam komisyon oranı ve dağılım yüzdelerini buradan yönetebilirsin.</CardDescription>

          <div className="mt-4 grid gap-3">
            <label className="grid gap-1">
              <span className="text-xs text-[var(--muted)]">Politika adı</span>
              <Input value={form.name} onChange={(e) => updateField('name', e.target.value)} />
            </label>
            <label className="grid gap-1">
              <span className="text-xs text-[var(--muted)]">Toplam komisyon oranı (%)</span>
              <Input value={form.commissionRatePercent} onChange={(e) => updateField('commissionRatePercent', e.target.value)} />
            </label>
          </div>
        </Card>

        <Card>
          <CardTitle>Dağılım (%)</CardTitle>
          <CardDescription className="mt-1">Toplam mutlaka %100 olmalı.</CardDescription>

          <div className="mt-4 grid grid-cols-2 gap-3">
            <label className="grid gap-1">
              <span className="text-xs text-[var(--muted)]">İş Ortağı</span>
              <Input value={form.hunterPercent} onChange={(e) => updateField('hunterPercent', e.target.value)} />
            </label>
            <label className="grid gap-1">
              <span className="text-xs text-[var(--muted)]">Danışman</span>
              <Input value={form.consultantPercent} onChange={(e) => updateField('consultantPercent', e.target.value)} />
            </label>
            <label className="grid gap-1">
              <span className="text-xs text-[var(--muted)]">Broker</span>
              <Input value={form.brokerPercent} onChange={(e) => updateField('brokerPercent', e.target.value)} />
            </label>
            <label className="grid gap-1">
              <span className="text-xs text-[var(--muted)]">Sistem</span>
              <Input value={form.systemPercent} onChange={(e) => updateField('systemPercent', e.target.value)} />
            </label>
          </div>

          <div className="mt-3 text-xs text-[var(--muted)]">
            Toplam dağılım: <span className={splitIsValid ? 'text-[var(--success)]' : 'text-[var(--danger)]'}>%{splitTotalPercent.toFixed(2)}</span>
          </div>
        </Card>
      </div>

      <Card className="mt-3">
        <CardTitle>Örnek Hesap</CardTitle>
        <CardDescription className="mt-1">10.000.000 TL satış ve %{form.commissionRatePercent || '0'} komisyon için dağıtım.</CardDescription>
        <div className="mt-3 grid gap-1 text-sm text-[var(--muted)]">
          <div>
            Toplam komisyon:
            <span className="ml-2 text-[var(--text)]">
              {Number.isFinite(Number(form.commissionRatePercent.replace(',', '.')))
                ? `${((10_000_000 * (Number(form.commissionRatePercent.replace(',', '.')) || 0)) / 100).toLocaleString('tr-TR')} TL`
                : '-'}
            </span>
          </div>
          <div>Dağılım toplamı %100 değilse kayıt yapılamaz.</div>
        </div>
      </Card>

      {error ? <Alert type="error" message={error} className="mt-3" /> : null}
      {success ? <Alert type="success" message={success} className="mt-3" /> : null}
      {!loading && activePolicy ? (
        <Alert
          type="info"
          className="mt-3"
          message={`Aktif policy: ${activePolicy.name} (${new Date(activePolicy.effectiveFrom).toLocaleString('tr-TR')})`}
        />
      ) : null}

      <div className="mt-4 flex items-center gap-2">
        <Button variant="secondary" onClick={() => void load()} disabled={loading || saving}>Yenile</Button>
        <Button variant="primary" onClick={() => void onSave()} loading={saving} disabled={loading || !splitIsValid}>Kaydet</Button>
      </div>
    </RoleShell>
  );
}
