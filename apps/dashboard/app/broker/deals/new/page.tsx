'use client';

function getApiMsg(e: unknown, fallback: string) {
  if (typeof e === 'string') return e;
  if (e && typeof e === 'object') {
    const msg = (e as Record<string, unknown>)['message'];
    if (typeof msg === 'string') return msg;
  }
  return fallback;
}


import { useEffect, useMemo, useState } from 'react';
import { api } from '@/lib/api';
import { requireAuth } from '@/lib/auth';

export default function NewDealPage() {
  const [leadId, setLeadId] = useState('');
  const [salePrice, setSalePrice] = useState<number>(5000000);
  const [commissionRate, setCommissionRate] = useState<number>(0.04);
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    requireAuth();
  }, []);

  const commissionTotal = useMemo(() => Number((salePrice * commissionRate).toFixed(2)), [salePrice, commissionRate]);

  async function createDeal() {
    setMsg(null);
    try {
      const res = await api.post('/broker/deals', { leadId, salePrice, commissionRate });
      setMsg(`Deal created: ${res.data.id}`);
      window.location.href = `/broker/deals/${res.data.id}/ledger`;
    } catch (err: unknown) {
      setMsg(getApiMsg(err, 'Create deal failed'));
    }
  }

  return (
    <div style={{ maxWidth: 680, margin: '24px auto', fontFamily: 'system-ui' }}>
      <h1>Create Deal</h1>

      <div style={{ display: 'grid', gap: 10 }}>
        <label>
          Lead ID
          <input value={leadId} onChange={(e) => setLeadId(e.target.value)} style={{ width: '100%', padding: 10 }} />
        </label>

        <label>
          Sale Price
          <input
            type="number"
            value={salePrice}
            onChange={(e) => setSalePrice(Number(e.target.value))}
            style={{ width: '100%', padding: 10 }}
          />
        </label>

        <label>
          Commission Rate (e.g. 0.04)
          <input
            type="number"
            step="0.001"
            value={commissionRate}
            onChange={(e) => setCommissionRate(Number(e.target.value))}
            style={{ width: '100%', padding: 10 }}
          />
        </label>

        <div style={{ color: '#666' }}>Commission Total: {commissionTotal}</div>

        <button onClick={createDeal} style={{ padding: 12 }}>
          Create Deal
        </button>

        <button onClick={() => (window.location.href = '/broker/leads/pending')} style={{ padding: 12 }}>
          Back
        </button>

        {msg && <div style={{ color: msg.startsWith('Deal created') ? 'green' : 'crimson' }}>{msg}</div>}
      </div>
    </div>
  );
}
