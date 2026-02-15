'use client';

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { requireRole } from '@/lib/auth';

export default function HunterDashboardPage() {
  const [allowed, setAllowed] = React.useState(false);

  React.useEffect(() => {
    setAllowed(requireRole(['HUNTER']));
  }, []);

  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="HUNTER"
      title="Hunter Paneli"
      subtitle="Lead oluştur, akışı takip et ve broker kuyruğunu besle."
      nav={[
        { href: '/hunter', label: 'Panel' },
        { href: '/hunter/leads', label: 'Leadlerim' },
        { href: '/hunter/leads/new', label: 'Yeni Lead' },
      ]}
    >
      <div style={{ border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
        <div style={{ fontWeight: 700, marginBottom: 8 }}>Hızlı Aksiyon</div>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          <a
            href="/hunter/leads/new"
            style={{
              display: 'inline-flex',
              textDecoration: 'none',
              color: '#1f1b16',
              border: '1px solid #d7cfbf',
              borderRadius: 10,
              padding: '10px 14px',
              fontWeight: 700,
            }}
          >
            Lead Gönder
          </a>
          <a
            href="/hunter/leads"
            style={{
              display: 'inline-flex',
              textDecoration: 'none',
              color: '#1f1b16',
              border: '1px solid #d7cfbf',
              borderRadius: 10,
              padding: '10px 14px',
              fontWeight: 700,
              background: '#fff',
            }}
          >
            Leadlerimi Gör
          </a>
        </div>
      </div>
    </RoleShell>
  );
}
