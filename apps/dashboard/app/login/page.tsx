'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useState } from 'react';
import { api, setToken } from '@/lib/api';

const API_BASE = (
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE ||
  'http://localhost:3001'
).replace(/\/+$/, '');



type Role = 'HUNTER' | 'BROKER' | 'CONSULTANT' | 'ADMIN' | string;

function roleHome(role: Role) {
  const r = (role || '').toUpperCase();
  if (r === 'HUNTER') return '/hunter';
  if (r === 'CONSULTANT') return '/consultant';
  if (r === 'BROKER') return '/broker';
  if (r === 'ADMIN') return '/broker';
  return '/login';
}

async function fetchMeRole(apiBase: string, token: string): Promise<Role> {
  const r = await fetch(`${apiBase}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  if (!r.ok) return '';
  const me = (await r.json()) as { role?: Role };
  return (me?.role || '') as Role;
}

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
      const token = ((res.data as any).access_token ?? (res.data as any).accessToken) as string;
      setToken(token);
      if (typeof window !== 'undefined') {
        window.localStorage.setItem('accessToken', token);
        document.cookie = `accessToken=${encodeURIComponent(token)}; Path=/; SameSite=Lax`;
      }
      window.location.href = roleHome(await fetchMeRole(API_BASE as any, token));
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
