'use client';

import { useEffect, useMemo, useState } from 'react';
import { api, clearToken } from '@/lib/api';
import { requireAuth } from '@/lib/auth';

type Lead = {
  id: string;
  category: string;
  status: string;
  title?: string | null;
  city?: string | null;
  district?: string | null;
  neighborhood?: string | null;
  price?: number | null;
  areaM2?: number | null;
  createdAt: string;
  createdBy?: { id: string; name: string; email: string; role: string } | null;
};

export default function PendingLeadsPage() {
  const [items, setItems] = useState<Lead[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionMsg, setActionMsg] = useState<string | null>(null);

  const title = useMemo(() => `Pending Leads (${items.length})`, [items.length]);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get('/broker/leads/pending');
      setItems(res.data);
    } catch (err: any) {
      setError(err?.response?.data?.message ?? 'Failed to load');
    } finally {
      setLoading(false);
    }
  }

  async function approve(id: string) {
    setActionMsg(null);
    try {
      await api.post(`/broker/leads/${id}/approve`, { brokerNote: 'OK' });
      setActionMsg('Approved.');
      await load();
    } catch (err: any) {
      setActionMsg(err?.response?.data?.message ?? 'Approve failed');
    }
  }

  async function reject(id: string) {
    setActionMsg(null);
    try {
      await api.post(`/broker/leads/${id}/reject`, { brokerNote: 'Rejected' });
      setActionMsg('Rejected.');
      await load();
    } catch (err: any) {
      setActionMsg(err?.response?.data?.message ?? 'Reject failed');
    }
  }

  useEffect(() => {
    requireAuth();
    load();
  }, []);

  return (
    <div style={{ maxWidth: 980, margin: '24px auto', fontFamily: 'system-ui' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>{title}</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={load}>Refresh</button>
          <button
            onClick={() => {
              clearToken();
              window.location.href = '/login';
            }}
          >
            Logout
          </button>
        </div>
      </div>

      {loading && <p>Loading...</p>}
      {error && <p style={{ color: 'crimson' }}>{error}</p>}
      {actionMsg && <p style={{ color: '#333' }}>{actionMsg}</p>}

      <div style={{ display: 'grid', gap: 12 }}>
        {items.map((l) => (
          <div key={l.id} style={{ border: '1px solid #ddd', borderRadius: 10, padding: 12 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
              <div>
                <div style={{ fontWeight: 700 }}>
                  {l.title || '(No title)'} — {l.category} — {l.status}
                </div>
                <div style={{ color: '#666' }}>
                  {l.city || '-'} / {l.district || '-'} / {l.neighborhood || '-'}
                </div>
                <div style={{ color: '#666' }}>
                  Price: {l.price ?? '-'} | m²: {l.areaM2 ?? '-'}
                </div>
                <div style={{ color: '#666' }}>
                  By: {l.createdBy?.name ?? '-'} ({l.createdBy?.role ?? '-'})
                </div>
              </div>

              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <button onClick={() => approve(l.id)}>Approve</button>
                <button onClick={() => reject(l.id)}>Reject</button>
                <button onClick={() => (window.location.href = `/broker/deals/new?leadId=${l.id}`)}>
                  Create Deal
                </button>
              </div>
            </div>

            <div style={{ marginTop: 10, color: '#999', fontSize: 12 }}>
              LeadId: {l.id}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
