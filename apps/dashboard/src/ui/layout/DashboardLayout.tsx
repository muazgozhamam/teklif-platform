'use client';

import React from 'react';
import { cn } from '../lib/cn';
import Sidebar from './Sidebar';
import Topbar from './Topbar';
import type { NavItem, ShellRole } from './role-nav';
import { getRoleNavSections } from './role-nav';

export default function DashboardLayout({
  role,
  title,
  nav,
  headerControls,
  children,
}: {
  role: ShellRole;
  title: string;
  nav?: NavItem[];
  headerControls?: React.ReactNode;
  children: React.ReactNode;
}) {
  const [mobileOpen, setMobileOpen] = React.useState(false);
  const envRaw = (process.env.NEXT_PUBLIC_APP_ENV || 'local').toUpperCase();
  const envLabel = envRaw === 'PROD' ? 'CANLI' : envRaw === 'STAGING' ? 'STAGE' : 'LOCAL';
  const navSections = React.useMemo(() => getRoleNavSections(role, nav ?? []), [role, nav]);

  return (
    <div className="h-screen w-full overflow-hidden bg-[var(--bg)] text-[var(--text)]">
      {mobileOpen ? <button type="button" className="fixed inset-0 z-40 bg-black/40 md:hidden" onClick={() => setMobileOpen(false)} aria-label="Menüyü kapat" /> : null}
      <div className="flex h-full w-full">
        <Sidebar role={role} navSections={navSections} mobileOpen={mobileOpen} onNavigate={() => setMobileOpen(false)} />
        <div className="min-w-0 flex h-full flex-1 flex-col overflow-hidden md:ml-0">
          <Topbar title={title} envLabel={envLabel} onMenu={() => setMobileOpen((s) => !s)} headerControls={headerControls} />
          <main className={cn('flex-1 overflow-auto px-4 py-5 md:px-6 md:py-6')}>{children}</main>
        </div>
      </div>
    </div>
  );
}
