'use client';

import React from 'react';
import { cn } from '../lib/cn';
import Sidebar from './Sidebar';
import Topbar from './Topbar';
import type { NavItem, ShellRole } from './role-nav';
import { getRoleNav } from './role-nav';

export default function DashboardLayout({
  role,
  title,
  nav,
  children,
}: {
  role: ShellRole;
  title: string;
  nav?: NavItem[];
  children: React.ReactNode;
}) {
  const [mobileOpen, setMobileOpen] = React.useState(false);
  const envRaw = (process.env.NEXT_PUBLIC_APP_ENV || 'local').toUpperCase();
  const envLabel = envRaw === 'PROD' ? 'CANLI' : envRaw === 'STAGING' ? 'STAGE' : 'LOCAL';
  const mergedNav = React.useMemo(() => getRoleNav(role, nav ?? []), [role, nav]);

  return (
    <div className="h-screen w-full overflow-hidden bg-[var(--bg)] text-[var(--text)]">
      {mobileOpen ? <button type="button" className="fixed inset-0 z-40 bg-black/40 md:hidden" onClick={() => setMobileOpen(false)} aria-label="Menüyü kapat" /> : null}
      <div className="flex h-full w-full">
        <Sidebar role={role} nav={mergedNav} mobileOpen={mobileOpen} onNavigate={() => setMobileOpen(false)} />
        <div className="min-w-0 flex h-full flex-1 flex-col overflow-hidden md:ml-0">
          <Topbar title={title} envLabel={envLabel} onMenu={() => setMobileOpen((s) => !s)} />
          <main className={cn('flex-1 overflow-auto px-4 py-5 md:px-6 md:py-6')}>{children}</main>
        </div>
      </div>
    </div>
  );
}
