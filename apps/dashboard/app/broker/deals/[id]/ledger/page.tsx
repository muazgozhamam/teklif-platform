'use client';
import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { api } from '@/lib/api';
import { requireRole } from '@/lib/auth';

function getApiMsg(e: unknown, fallback: string) {
  if (typeof e === 'string') return e;
  if (e && typeof e === 'object') {
    const ro = e as Record<string, unknown>;
    const m = ro['message'];
    if (typeof m === 'string') return m;
    const resp = ro['response'];
    if (resp && typeof resp === 'object') {
      const data = (resp as Record<string, unknown>)['data'];
      if (data && typeof data === 'object') {
        const dm = (data as Record<string, unknown>)['message'];
        if (typeof dm === 'string') return dm;
      }
    }
  }
  return fallback;
}

type Deal = {
  id: string;
  leadId: string;
  salePrice: number;
  commissionRate: number;
  commissionTotal: number;
};

type LedgerRow = {
  id: string;
  beneficiaryRole: string;
  level?: number | null;
  percent: number;
  amount: number;
  note?: string | null;
  beneficiaryUser?: { id: string; name: string; email: string; role: string } | null;
};

type AuditRow = {
  id: string;
  createdAt: string;
  action: string;
  actorEmail?: string | null;
  actorRole?: string | null;
  metaJson?: Record<string, unknown> | null;
};

export default function LedgerPage() {
  const params = useParams<{ id: string }>();
  const dealId = String(params?.id ?? '');
  const [allowed] = useState(() => requireRole(['BROKER', 'ADMIN']));
  const [rows, setRows] = useState<LedgerRow[]>([]);
  const [deal, setDeal] = useState<Deal | null>(null);
  const [auditRows, setAuditRows] = useState<AuditRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    if (!dealId) return;
    setError(null);
    try {
      const res = await api.get(`/broker/deals/${dealId}/ledger`);
      setDeal(res.data.deal);
      setRows(res.data.ledger);
      const audit = await api.get<AuditRow[]>(`/audit/entity/DEAL/${dealId}`);
      setAuditRows(Array.isArray(audit.data) ? audit.data : []);
    } catch (err: unknown) {
      setError(getApiMsg(err, 'Defter yüklenemedi'));
    }
  }

  useEffect(() => {
    if (!allowed) return;
    const t = window.setTimeout(() => {
      void load();
    }, 0);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allowed, dealId]);

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
      title="Deal Defteri"
      subtitle="Deal dağılım ve audit kayıtlarını incele."
      nav={[
        { href: '/broker', label: 'Panel' },
        { href: '/broker/leads/pending', label: 'Bekleyen Leadler' },
        { href: '/broker/deals/new', label: 'Yeni Deal' },
        { href: '/broker/hunter-applications', label: 'Hunter Başvuruları' },
      ]}
    >
      <div style={{ maxWidth: 980, margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>Deal Defteri</h1>
        <button onClick={() => (window.location.href = '/broker/leads/pending')}>Bekleyenlere Dön</button>
      </div>

      {error ? <AlertMessage type="error" message={error} /> : null}

      {deal && (
        <div style={{ border: '1px solid #ddd', borderRadius: 10, padding: 12, marginBottom: 12 }}>
          <div><b>Deal ID:</b> {deal.id}</div>
          <div><b>Lead ID:</b> {deal.leadId}</div>
          <div><b>Satış Fiyatı:</b> {deal.salePrice}</div>
          <div><b>Komisyon Oranı:</b> {deal.commissionRate}</div>
          <div><b>Toplam Komisyon:</b> {deal.commissionTotal}</div>
        </div>
      )}

      <div style={{ display: 'grid', gap: 10 }}>
        {rows.map((r) => (
          <div key={r.id} style={{ border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontWeight: 700 }}>
              {r.beneficiaryUser ? `${r.beneficiaryUser.name} (${r.beneficiaryUser.role})` : 'PLATFORM'}
            </div>
            <div style={{ color: '#666' }}>
              rol={r.beneficiaryRole} seviye={r.level ?? '-'} yüzde={r.percent} tutar={r.amount}
            </div>
            {r.note && <div style={{ color: '#999' }}>{r.note}</div>}
          </div>
        ))}
      </div>

      <div style={{ marginTop: 16, border: '1px solid #ddd', borderRadius: 10, padding: 12 }}>
        <div style={{ fontWeight: 700, marginBottom: 8 }}>Denetim Zaman Çizelgesi</div>
        {auditRows.length === 0 ? (
          <div style={{ color: '#666', fontSize: 13 }}>Audit kaydı bulunamadı.</div>
        ) : (
          <div style={{ display: 'grid', gap: 8 }}>
            {auditRows.map((a) => (
              <div key={a.id} style={{ border: '1px solid #eee', borderRadius: 8, padding: 10 }}>
                <div style={{ fontSize: 12, color: '#666' }}>
                  {new Date(a.createdAt).toLocaleString()} • {a.actorEmail || a.actorRole || 'system'}
                </div>
                <div style={{ marginTop: 2, fontWeight: 700 }}>{a.action}</div>
              </div>
            ))}
          </div>
        )}
      </div>
      </div>
    </RoleShell>
  );
}
