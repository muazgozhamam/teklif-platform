'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useEffect, useState } from 'react';
import { api, setToken } from '@/lib/api';
import { roleHomePath } from '@/lib/roles';
import { decodeJwtPayload } from '@/lib/session';
import { useSearchParams } from 'next/navigation';
import Logo from '@/components/brand/Logo';

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
  const searchParams = useSearchParams();
  const [email, setEmail] = useState('admin@local.dev');
  const [password, setPassword] = useState('admin123');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const token = searchParams.get('access_token');
    if (!token) return;

    setToken(token);
    const jwt = decodeJwtPayload(token);
    const resolvedSub = String(jwt?.sub || '').trim();
    const resolvedRole = String(jwt?.role || '').trim();
    if (typeof window !== 'undefined') {
      if (resolvedSub) window.localStorage.setItem('x-user-id', resolvedSub);
      window.location.replace(roleHomePath(resolvedRole || ''));
    }
  }, [searchParams]);

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
      <h1 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <Logo size="md" />
        <span>Panel Girişi</span>
      </h1>
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
