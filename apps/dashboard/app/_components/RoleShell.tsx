'use client';

import React from 'react';
import { Badge } from '@/src/ui/components/Badge';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import DashboardLayout from '@/src/ui/layout/DashboardLayout';
import type { NavItem, ShellRole } from '@/src/ui/layout/role-nav';

type RoleShellProps = {
  role: ShellRole;
  title: string;
  subtitle?: string;
  nav: NavItem[];
  children: React.ReactNode;
};

export default function RoleShell({ role, title, subtitle, nav, children }: RoleShellProps) {
  return (
    <DashboardLayout role={role} title={title} nav={nav}>
      <Card className="mb-4 border-[var(--border)] bg-[var(--card-2)]">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-[18px] md:text-[20px]">{title}</CardTitle>
            {subtitle ? <CardDescription className="mt-1.5 text-[13px]">{subtitle}</CardDescription> : null}
          </div>
          <Badge variant="primary">Operasyon görünümü aktif</Badge>
        </div>
      </Card>
      {children}
    </DashboardLayout>
  );
}
