'use client';

import { useEffect, useState } from 'react';

type Role = 'HUNTER' | 'BROKER' | 'CONSULTANT' | 'ADMIN' | string;

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  'http://localhost:3001';

function roleHome(role: Role) {
  const r = (role || '').toUpperCase();
  if (r === 'HUNTER') return '/hunter';
  if (r === 'CONSULTANT') return '/consultant';
  if (r === 'BROKER') return '/broker';
  if (r === 'ADMIN') return '/broker';
  return '/login';
}

export default function BrokerRootPage() {
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
          headers: { Authorization: `Bearer ${token}` },
          cache: 'no-store',
        });

        if (r.status === 401) {
          window.location.href = '/login';
          return;
        }
        if (!r.ok) {
          window.location.href = '/login';
          return;
        }

        const me = (await r.json()) as { role?: Role };
        const role = (me?.role || '').toUpperCase();

        // broker/admin değilse kendi home’una
        if (role !== 'BROKER' && role !== 'ADMIN') {
          window.location.href = roleHome(role);
          return;
        }

        setReady(true);

        // broker landing
        window.location.href = '/broker/leads/pending';
      } catch {
        window.location.href = '/login';
      }
    })();
  }, []);

  return (
    <div style={{ padding: 24, opacity: 0.85 }}>
      {ready ? 'Yönlendiriliyor…' : 'Yükleniyor…'}
    </div>
  );
}
