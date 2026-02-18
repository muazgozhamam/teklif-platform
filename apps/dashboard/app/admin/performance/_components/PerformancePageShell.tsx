'use client';

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import PerformanceFilterBar from './PerformanceFilterBar';

export default function PerformancePageShell({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  return (
    <RoleShell
      role="ADMIN"
      title={title}
      subtitle={subtitle || 'Performans ve analytics görünümü.'}
      nav={[
        { href: '/admin', label: 'Panel' },
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/audit', label: 'Denetim' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >
      <PerformanceFilterBar />
      {children}
    </RoleShell>
  );
}
