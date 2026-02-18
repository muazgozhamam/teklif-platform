'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';
import { Button } from '@/src/ui/components/Button';
import { Alert } from '@/src/ui/components/Alert';
import { api } from '@/lib/api';

type PayoutRow = { allocationId: string; amountMinor: string };

export default function AdminCommissionPayoutsPage() {
  const [rows, setRows] = React.useState<PayoutRow[]>([{ allocationId: '', amountMinor: '' }]);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [ok, setOk] = React.useState<string | null>(null);
  const [method, setMethod] = React.useState<'BANK_TRANSFER' | 'CASH' | 'OTHER'>('BANK_TRANSFER');
  const [referenceNo, setReferenceNo] = React.useState('');

  function updateRow(index: number, next: Partial<PayoutRow>) {
    setRows((prev) => prev.map((row, i) => (i === index ? { ...row, ...next } : row)));
  }

  function addRow() {
    setRows((prev) => [...prev, { allocationId: '', amountMinor: '' }]);
  }

  function removeRow(index: number) {
    setRows((prev) => prev.filter((_, i) => i !== index));
  }

  async function submit() {
    setSaving(true);
    setError(null);
    setOk(null);
    try {
      const allocations = rows
        .map((r) => ({ allocationId: r.allocationId.trim(), amountMinor: r.amountMinor.trim() }))
        .filter((r) => r.allocationId && r.amountMinor);

      if (allocations.length === 0) {
        setError('En az bir allocation satırı doldurmalısın.');
        return;
      }

      await api.post('/admin/commission/payouts', {
        paidAt: new Date().toISOString(),
        method,
        referenceNo: referenceNo.trim() || undefined,
        allocations,
      });

      setRows([{ allocationId: '', amountMinor: '' }]);
      setReferenceNo('');
      setOk('Payout kaydı oluşturuldu.');
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Payout işlemi başarısız.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <RoleShell role="ADMIN" title="Hakediş Ödemeleri" subtitle="Onaylı allocation satırlarına ödeme kaydı oluştur." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}
      {ok ? <Alert type="success" message={ok} className="mb-4" /> : null}

      <Card>
        <CardTitle>Yeni Payout</CardTitle>
        <CardDescription>Tutarlar minor units (kuruş) olarak girilir. Örn: 12.345,67 TL = 1234567</CardDescription>

        <div className="mt-3 grid gap-3 md:grid-cols-3">
          <div>
            <label className="mb-1 block text-xs text-[var(--muted)]">Ödeme Yöntemi</label>
            <select
              value={method}
              onChange={(e) => setMethod(e.target.value as 'BANK_TRANSFER' | 'CASH' | 'OTHER')}
              className="ui-interactive h-10 w-full rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
            >
              <option value="BANK_TRANSFER">Banka Transferi</option>
              <option value="CASH">Nakit</option>
              <option value="OTHER">Diğer</option>
            </select>
          </div>
          <div className="md:col-span-2">
            <label className="mb-1 block text-xs text-[var(--muted)]">Referans No (opsiyonel)</label>
            <Input value={referenceNo} onChange={(e) => setReferenceNo(e.target.value)} placeholder="Banka işlem no" />
          </div>
        </div>

        <div className="mt-4 space-y-2">
          {rows.map((row, index) => (
            <div key={index} className="grid gap-2 md:grid-cols-[1fr_200px_auto]">
              <Input
                placeholder="Allocation ID"
                value={row.allocationId}
                onChange={(e) => updateRow(index, { allocationId: e.target.value })}
              />
              <Input
                placeholder="Amount Minor"
                value={row.amountMinor}
                onChange={(e) => updateRow(index, { amountMinor: e.target.value })}
              />
              <Button variant="ghost" onClick={() => removeRow(index)} disabled={rows.length === 1}>Sil</Button>
            </div>
          ))}
        </div>

        <div className="mt-4 flex flex-wrap gap-2">
          <Button variant="secondary" onClick={addRow}>Satır Ekle</Button>
          <Button onClick={submit} disabled={saving}>{saving ? 'Kaydediliyor…' : 'Payout Oluştur'}</Button>
        </div>
      </Card>
    </RoleShell>
  );
}
