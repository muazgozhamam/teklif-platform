#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
APP="$ROOT/apps/dashboard"

if [ ! -d "$APP" ]; then
  echo "apps/dashboard not found. Create Next app first."
  exit 1
fi

echo "==> Writing dashboard env..."
cat > "$APP/.env.local" <<'ENV'
NEXT_PUBLIC_API_BASE_URL=http://localhost:3001
ENV

echo "==> Installing dependencies..."
cd "$APP"
pnpm add axios zod

echo "==> Writing API client..."
mkdir -p "$APP/lib"
cat > "$APP/lib/api.ts" <<'TS'
import axios from 'axios';

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001';

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('accessToken');
}

export function setToken(token: string) {
  localStorage.setItem('accessToken', token);
}

export function clearToken() {
  localStorage.removeItem('accessToken');
}

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config) => {
  const token = getToken();
  if (token) {
    config.headers = config.headers ?? {};
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
TS

echo "==> Writing simple auth guard helper..."
cat > "$APP/lib/auth.ts" <<'TS'
export function requireAuth() {
  if (typeof window === 'undefined') return;
  const token = localStorage.getItem('accessToken');
  if (!token) window.location.href = '/login';
}
TS

echo "==> Writing Root page redirect..."
mkdir -p "$APP/app"
cat > "$APP/app/page.tsx" <<'TSX'
'use client';

import { useEffect } from 'react';

export default function Home() {
  useEffect(() => {
    const token = localStorage.getItem('accessToken');
    window.location.href = token ? '/broker/leads/pending' : '/login';
  }, []);

  return null;
}
TSX

echo "==> Writing Login page..."
mkdir -p "$APP/app/login"
cat > "$APP/app/login/page.tsx" <<'TSX'
'use client';

import { useState } from 'react';
import { api, setToken } from '@/lib/api';

export default function LoginPage() {
  const [email, setEmail] = useState('admin@teklif.local');
  const [password, setPassword] = useState('Admin123!');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api.post('/auth/login', { email, password });
      setToken(res.data.accessToken);
      window.location.href = '/broker/leads/pending';
    } catch (err: any) {
      setError(err?.response?.data?.message ?? 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: 420, margin: '40px auto', fontFamily: 'system-ui' }}>
      <h1>Dashboard Login</h1>
      <p style={{ color: '#666' }}>API: {process.env.NEXT_PUBLIC_API_BASE_URL}</p>

      <form onSubmit={onSubmit} style={{ display: 'grid', gap: 12 }}>
        <label>
          Email
          <input value={email} onChange={(e) => setEmail(e.target.value)} style={{ width: '100%', padding: 10 }} />
        </label>

        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={{ width: '100%', padding: 10 }} />
        </label>

        <button disabled={loading} style={{ padding: 12 }}>
          {loading ? 'Logging in...' : 'Login'}
        </button>

        {error && <div style={{ color: 'crimson' }}>{error}</div>}
      </form>
    </div>
  );
}
TSX

echo "==> Writing Broker Pending Leads page..."
mkdir -p "$APP/app/broker/leads/pending"
cat > "$APP/app/broker/leads/pending/page.tsx" <<'TSX'
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
TSX

echo "==> Writing Deal Create page..."
mkdir -p "$APP/app/broker/deals/new"
cat > "$APP/app/broker/deals/new/page.tsx" <<'TSX'
'use client';

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
    const url = new URL(window.location.href);
    const qLeadId = url.searchParams.get('leadId');
    if (qLeadId) setLeadId(qLeadId);
  }, []);

  const commissionTotal = useMemo(() => Number((salePrice * commissionRate).toFixed(2)), [salePrice, commissionRate]);

  async function createDeal() {
    setMsg(null);
    try {
      const res = await api.post('/broker/deals', { leadId, salePrice, commissionRate });
      setMsg(`Deal created: ${res.data.id}`);
      window.location.href = `/broker/deals/${res.data.id}/ledger`;
    } catch (err: any) {
      setMsg(err?.response?.data?.message ?? 'Create deal failed');
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
TSX

echo "==> Writing Ledger page..."
mkdir -p "$APP/app/broker/deals/[id]/ledger"
cat > "$APP/app/broker/deals/[id]/ledger/page.tsx" <<'TSX'
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
TSX

echo "==> Done."
echo "Next:"
echo "  cd apps/dashboard && pnpm dev"
echo "Open:"
echo "  http://localhost:3000"
echo ""
echo "Login then go to Broker Pending:"
echo "  /broker/leads/pending"
