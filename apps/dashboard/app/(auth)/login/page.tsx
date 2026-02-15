'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useState } from 'react';
import { api, setToken } from '@/lib/api';
import { roleHomePath } from '@/lib/roles';
import { decodeJwtPayload } from '@/lib/session';

const API_BASE = (
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE ||
  'http://localhost:3001'
).replace(/\/+$/, '');

async function fetchMe(apiBase: string, token: string): Promise<{ sub?: string; role?: string }> {
  const r = await fetch(`${apiBase}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  if (!r.ok) return {};
  return (await r.json()) as { sub?: string; role?: string };
}

export default function LoginPage() {
  const [email, setEmail] = useState('admin@local.dev');
  const [password, setPassword] = useState('admin123');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api.post('/auth/login', { email, password });
      const token = ((res.data as any).access_token ?? (res.data as any).accessToken) as string;
      setToken(token);

      const me = await fetchMe(API_BASE, token);
      const jwt = decodeJwtPayload(token);

      const resolvedSub = String(me?.sub || jwt?.sub || '').trim();
      const resolvedRole = String(me?.role || jwt?.role || '').trim();

      if (typeof window !== 'undefined') {
        if (resolvedSub) window.localStorage.setItem('x-user-id', resolvedSub);
      }

      window.location.href = roleHomePath(resolvedRole || me?.role || '');
    } catch (err: any) {
      setError(err?.response?.data?.message ?? 'Giriş başarısız');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: 420, margin: '40px auto', fontFamily: 'system-ui' }}>
      <h1>satdedi.com Panel Girişi</h1>
      <p style={{ color: '#666' }}>API: {process.env.NEXT_PUBLIC_API_BASE_URL}</p>

      <form onSubmit={onSubmit} style={{ display: 'grid', gap: 12 }}>
        <label>
          E-posta
          <input value={email} onChange={(e) => setEmail(e.target.value)} style={{ width: '100%', padding: 10 }} />
        </label>

        <label>
          Şifre
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={{ width: '100%', padding: 10 }} />
        </label>

        <button disabled={loading} style={{ padding: 12 }}>
          {loading ? 'Giriş yapılıyor...' : 'Giriş Yap'}
        </button>

        {error && <div style={{ color: 'crimson' }}>{error}</div>}
      </form>
    </div>
  );
}
