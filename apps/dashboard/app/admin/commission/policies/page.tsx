'use client';

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Alert } from '@/src/ui/components/Alert';
import { Button } from '@/src/ui/components/Button';
import { Input } from '@/src/ui/components/Input';
import { api } from '@/lib/api';

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

export default function AdminCommissionPoliciesPage() {
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
    <RoleShell
      role="ADMIN"
      title="Komisyon Politikaları"
      subtitle="Komisyon oranlarını ve dağıtım paylarını buradan yönetirsiniz."
      nav={[]}
    >
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
        <CardDescription className="mt-1">
          10.000.000 TL satış ve %{form.commissionRatePercent || '0'} komisyon için dağıtım.
        </CardDescription>
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
        <Button variant="secondary" onClick={() => void load()} disabled={loading || saving}>
          Yenile
        </Button>
        <Button variant="primary" onClick={() => void onSave()} loading={saving} disabled={loading || !splitIsValid}>
          Kaydet
        </Button>
      </div>
    </RoleShell>
  );
}
