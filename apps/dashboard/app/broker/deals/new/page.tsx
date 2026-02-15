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
import { requireRole } from '@/lib/auth';

export default function NewDealPage() {
  const [leadId, setLeadId] = useState('');
  const [salePrice, setSalePrice] = useState<number>(5000000);
  const [commissionRate, setCommissionRate] = useState<number>(0.04);
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    requireRole(['BROKER', 'ADMIN']);
  }, []);

  const commissionTotal = useMemo(() => Number((salePrice * commissionRate).toFixed(2)), [salePrice, commissionRate]);

  async function createDeal() {
    setMsg(null);
    try {
      const res = await api.post('/broker/deals', { leadId, salePrice, commissionRate });
      setMsg(`Deal oluşturuldu: ${res.data.id}`);
      window.location.href = `/broker/deals/${res.data.id}/ledger`;
    } catch (err: unknown) {
      setMsg(getApiMsg(err, 'Deal oluşturma başarısız'));
    }
  }

  return (
    <div style={{ maxWidth: 680, margin: '24px auto', fontFamily: 'system-ui' }}>
      <h1>Deal Oluştur</h1>

      <div style={{ display: 'grid', gap: 10 }}>
        <label>
          Lead ID
          <input value={leadId} onChange={(e) => setLeadId(e.target.value)} style={{ width: '100%', padding: 10 }} />
        </label>

        <label>
          Satış Fiyatı
          <input
            type="number"
            value={salePrice}
            onChange={(e) => setSalePrice(Number(e.target.value))}
            style={{ width: '100%', padding: 10 }}
          />
        </label>

        <label>
          Komisyon Oranı (örn: 0.04)
          <input
            type="number"
            step="0.001"
            value={commissionRate}
            onChange={(e) => setCommissionRate(Number(e.target.value))}
            style={{ width: '100%', padding: 10 }}
          />
        </label>

        <div style={{ color: '#666' }}>Toplam Komisyon: {commissionTotal}</div>

        <button onClick={createDeal} style={{ padding: 12 }}>
          Deal Oluştur
        </button>

        <button onClick={() => (window.location.href = '/broker/leads/pending')} style={{ padding: 12 }}>
          Geri
        </button>

        {msg && <div style={{ color: msg.startsWith('Deal oluşturuldu') ? 'green' : 'crimson' }}>{msg}</div>}
      </div>
    </div>
  );
}
