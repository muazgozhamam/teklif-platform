'use client';

import { useEffect, useState } from 'react';

type Me = {
  id?: string;
  role?: string;
  email?: string | null;
};

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  'http://localhost:3001';


type Role = 'HUNTER' | 'BROKER' | 'CONSULTANT' | 'ADMIN' | string;

function roleHome(role: Role) {
  const r = (role || '').toUpperCase();
  if (r === 'HUNTER') return '/hunter';
  if (r === 'CONSULTANT') return '/consultant';
  if (r === 'BROKER') return '/broker';
  if (r === 'ADMIN') return '/broker';
  return '/login';
}


export default function HunterDashboardPage() {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    (async () => {
      const token = localStorage.getItem('accessToken');
      if (!token) {
        window.location.href = '/login';
        return;
      }

      try {
        const r = await fetch(`${API_BASE}/auth/me`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        if (r.status === 401) {
          window.location.href = '/login';
          return;
        }

        if (!r.ok) {
          window.location.href = '/login';
          return;
        }

        const me = (await r.json()) as Me;
        if ((me?.role || '').toUpperCase() !== 'HUNTER') {
          window.location.href = roleHome((me?.role || '') as Role);
          return;
        }

        setReady(true);
      } catch {
        window.location.href = '/login';
      }
    })();
  }, []);

  if (!ready) {
    return (
      <main style={{
        padding: 24,
        maxWidth: 960,
        margin: '0 auto',
        opacity: 0.8,
      }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <main>
      <h1 style={{
        fontSize: 24,
        fontWeight: 700,
        marginBottom: 8,
      }}>
        Hunter Dashboard
      </h1>

      <p style={{
        opacity: 0.8,
        marginBottom: 16,
      }}>
        Bu alan yalnızca HUNTER rolü içindir.
      </p>

      <div style={{
        border: '1px solid rgba(0,0,0,0.12)',
        borderRadius: 12,
        padding: 16,
      }}>
        
      <div style={{ display: 'flex', gap: 10, marginBottom: 16 }}>
        <a
          href="/hunter/leads/new"
          style={{
            padding: '10px 14px',
            borderRadius: 10,
            border: '1px solid rgba(0,0,0,0.18)',
            textDecoration: 'none',
            fontWeight: 600,
          }}
        >
          Lead Gönder
        </a>
      </div>

<div style={{ fontWeight: 600, marginBottom: 6 }}>
          Planlanan Modüller
        </div>
        <ul style={{ margin: 0, paddingLeft: 18, lineHeight: 1.7 }}>
          <li>Lead gönderme (skeleton)</li>
          <li>Gönderilen lead’ler listesi</li>
          <li>Durum: OPEN / MATCHED / CLOSED</li>
        </ul>
      </div>
    </main>
  );
}
