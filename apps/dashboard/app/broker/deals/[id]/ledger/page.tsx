'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { requireAuth } from '@/lib/auth';

type LedgerRow = {
  id: string;
  beneficiaryRole: string;
  level?: number | null;
  percent: number;
  amount: number;
  note?: string | null;
  beneficiaryUser?: { id: string; name: string; email: string; role: string } | null;
};

export default function LedgerPage({ params }: { params: { id: string } }) {
  const [rows, setRows] = useState<LedgerRow[]>([]);
  const [deal, setDeal] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setError(null);
    try {
      const res = await api.get(`/broker/deals/${params.id}/ledger`);
      setDeal(res.data.deal);
      setRows(res.data.ledger);
    } catch (err: any) {
      setError(err?.response?.data?.message ?? 'Failed to load ledger');
    }
  }

  useEffect(() => {
    requireAuth();
    load();
  }, []);

  return (
    <div style={{ maxWidth: 980, margin: '24px auto', fontFamily: 'system-ui' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>Deal Ledger</h1>
        <button onClick={() => (window.location.href = '/broker/leads/pending')}>Back to Pending</button>
      </div>

      {error && <p style={{ color: 'crimson' }}>{error}</p>}

      {deal && (
        <div style={{ border: '1px solid #ddd', borderRadius: 10, padding: 12, marginBottom: 12 }}>
          <div><b>Deal ID:</b> {deal.id}</div>
          <div><b>Lead ID:</b> {deal.leadId}</div>
          <div><b>Sale Price:</b> {deal.salePrice}</div>
          <div><b>Commission Rate:</b> {deal.commissionRate}</div>
          <div><b>Commission Total:</b> {deal.commissionTotal}</div>
        </div>
      )}

      <div style={{ display: 'grid', gap: 10 }}>
        {rows.map((r) => (
          <div key={r.id} style={{ border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontWeight: 700 }}>
              {r.beneficiaryUser ? `${r.beneficiaryUser.name} (${r.beneficiaryUser.role})` : 'PLATFORM'}
            </div>
            <div style={{ color: '#666' }}>
              role={r.beneficiaryRole} level={r.level ?? '-'} percent={r.percent} amount={r.amount}
            </div>
            {r.note && <div style={{ color: '#999' }}>{r.note}</div>}
          </div>
        ))}
      </div>
    </div>
  );
}
