'use client';

function getApiMsg(e: unknown, fallback: string) {
  if (typeof e === 'string') return e;
  if (e && typeof e === 'object') {
    const msg = (e as Record<string, unknown>)['message'];
    if (typeof msg === 'string') return msg;
  }
  return fallback;
}

import { useMemo, useState } from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { api } from '@/lib/api';
import { requireRole } from '@/lib/auth';

export default function NewDealPage() {
  const [allowed] = useState(() => requireRole(['BROKER', 'ADMIN']));
  const [leadId, setLeadId] = useState('');
  const [salePrice, setSalePrice] = useState<number>(5000000);
  const [commissionRate, setCommissionRate] = useState<number>(0.04);
  const [msg, setMsg] = useState<{ type: 'error' | 'success'; text: string } | null>(null);

  const commissionTotal = useMemo(() => Number((salePrice * commissionRate).toFixed(2)), [salePrice, commissionRate]);

  async function createDeal() {
    setMsg(null);
    try {
      const res = await api.post('/broker/deals', { leadId, salePrice, commissionRate });
      setMsg({ type: 'success', text: `Deal oluşturuldu: ${res.data.id}` });
      window.location.href = `/broker/deals/${res.data.id}/ledger`;
    } catch (err: unknown) {
      setMsg({ type: 'error', text: getApiMsg(err, 'Deal oluşturma başarısız') });
    }
  }

  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="BROKER"
      title="Deal Oluştur"
      subtitle="Lead üzerinden manuel deal aç."
      nav={[
        { href: '/broker', label: 'Panel' },
        { href: '/broker/leads/pending', label: 'Bekleyen Leadler' },
        { href: '/broker/deals/new', label: 'Yeni Deal' },
        { href: '/broker/hunter-applications', label: 'Hunter Başvuruları' },
      ]}
    >
      <div style={{ maxWidth: 680, margin: '0 auto' }}>
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

          {msg ? <AlertMessage type={msg.type} message={msg.text} /> : null}
        </div>
      </div>
    </RoleShell>
  );
}
