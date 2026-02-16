'use client';

import React from 'react';
import { roleLabelTr } from '@/lib/roles';
import Logo from '@/components/brand/Logo';

type NavItem = {
  href: string;
  label: string;
};

type RoleShellProps = {
  role: 'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER';
  title: string;
  subtitle?: string;
  nav: NavItem[];
  children: React.ReactNode;
};

export default function RoleShell({ role, title, subtitle, nav, children }: RoleShellProps) {
  const roleLabel = roleLabelTr(role);
  const envRaw = (process.env.NEXT_PUBLIC_APP_ENV || 'local').toUpperCase();
  const envLabel = envRaw === 'PROD' ? 'CANLI' : envRaw === 'STAGING' ? 'STAGING' : 'LOCAL';
  const envColor = envRaw === 'PROD' ? '#0a7f3f' : envRaw === 'STAGING' ? '#9a6600' : '#5f4a2e';

  return (
    <div style={{ minHeight: '100vh', background: 'linear-gradient(180deg, #faf7f2 0%, #ffffff 40%)' }}>
      <header style={{ borderBottom: '1px solid #ece7df', background: '#fffdf9' }}>
        <div style={{ maxWidth: 1140, margin: '0 auto', padding: '14px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div><Logo size="md" /></div>
            <span style={{ fontSize: 12, border: '1px solid #d8d1c7', color: '#6c6358', borderRadius: 999, padding: '3px 8px', background: '#f7f2ea' }}>
              {roleLabel}
            </span>
            <span
              style={{
                fontSize: 12,
                border: `1px solid ${envColor}33`,
                color: envColor,
                borderRadius: 999,
                padding: '3px 8px',
                background: `${envColor}12`,
                fontWeight: 700,
              }}
            >
              Ortam: {envLabel}
            </span>
          </div>
          <nav style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            {nav.map((item) => (
              <a
                key={item.href}
                href={item.href}
                style={{
                  textDecoration: 'none',
                  color: '#2f2a24',
                  border: '1px solid #ded8cd',
                  borderRadius: 999,
                  padding: '8px 12px',
                  background: '#ffffff',
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                {item.label}
              </a>
            ))}
          </nav>
        </div>
      </header>
      <main style={{ maxWidth: 1140, margin: '0 auto', padding: 24 }}>
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 800, color: '#1f1b16' }}>{title}</h1>
        {subtitle ? <p style={{ margin: '8px 0 0', color: '#6f665c' }}>{subtitle}</p> : null}
        <div
          style={{
            marginTop: 10,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            fontSize: 12,
            color: '#7a6f62',
            background: '#f8f3ec',
            border: '1px solid #e5ded1',
            borderRadius: 999,
            padding: '4px 10px',
          }}
        >
          <span aria-hidden style={{ width: 7, height: 7, borderRadius: '50%', background: envColor, display: 'inline-block' }} />
          Operasyon görünümü aktif
        </div>
        <div style={{ marginTop: 16 }}>{children}</div>
      </main>
    </div>
  );
}
