'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '../lib/cn';
import type { NavSection, ShellRole } from './role-nav';
import NavGroupAccordion from './NavGroupAccordion';
import { roleLabelTr } from '@/lib/roles';
import Logo from '@/components/brand/Logo';
import SidebarItem from './SidebarItem';

export default function Sidebar({
  role,
  navSections,
  mobileOpen,
  onNavigate,
}: {
  role: ShellRole;
  navSections: NavSection[];
  mobileOpen: boolean;
  onNavigate: () => void;
}) {
  const pathname = usePathname();
  const storageKey = `satdedi-sidebar-open:${role}`;

  const activeGroupId = React.useMemo(() => {
    for (const section of navSections) {
      for (const group of section.groups) {
        const hasActiveItem = group.items.some(
          (item) => pathname === item.href || (item.href !== `/${role.toLowerCase()}` && pathname.startsWith(item.href)),
        );
        if (hasActiveItem) return group.id;
      }
    }
    return null;
  }, [navSections, pathname, role]);

  const [openGroupId, setOpenGroupId] = React.useState<string | null>(null);

  React.useEffect(() => {
    const defaults = navSections.flatMap((section) => section.groups.filter((group) => group.defaultOpen).map((group) => group.id));
    let persisted: string | null = null;
    try {
      const raw = window.localStorage.getItem(storageKey);
      const parsed = raw ? (JSON.parse(raw) as unknown) : null;
      if (Array.isArray(parsed)) {
        // Backward compatibility for old multi-open storage format.
        persisted = parsed.find((v): v is string => typeof v === 'string') || null;
      } else if (typeof parsed === 'string') {
        persisted = parsed;
      }
    } catch {
      persisted = null;
    }
    setOpenGroupId(activeGroupId || persisted || defaults[0] || null);
  }, [storageKey, navSections, activeGroupId]);

  React.useEffect(() => {
    try {
      window.localStorage.setItem(storageKey, JSON.stringify(openGroupId));
    } catch {
      // ignore storage write errors
    }
  }, [openGroupId, storageKey]);

  function toggleGroup(groupId: string) {
    // Keep the active route's parent open; otherwise toggle single-open.
    if (groupId === activeGroupId) {
      setOpenGroupId(groupId);
      return;
    }
    setOpenGroupId((prev) => (prev === groupId ? null : groupId));
  }

  return (
    <aside
      className={cn(
        'fixed inset-y-0 left-0 z-50 h-screen w-[240px] overflow-y-auto border-r border-[var(--border)] bg-[var(--sidebar)] p-3 transition-transform md:static md:translate-x-0',
        mobileOpen ? 'translate-x-0' : '-translate-x-full',
      )}
    >
      <Link
        href="/"
        onClick={onNavigate}
        className="mb-4 flex h-10 items-center rounded-xl border border-[var(--border)] bg-[var(--card)] px-3"
        aria-label="Ana sayfaya dön"
      >
        <Logo size="md" />
      </Link>

      <div className="mb-4 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2">
        <div className="text-[11px] uppercase tracking-[0.08em] text-[var(--muted)]">Rol</div>
        <div className="mt-1 text-sm font-medium text-[var(--text)]">{roleLabelTr(role)}</div>
      </div>

      <nav className="space-y-4">
        {navSections.map((section) => (
          <div key={section.id} className="space-y-2">
            <div className="px-2 text-[11px] uppercase tracking-[0.08em] text-[var(--muted)]">{section.title}</div>
            <div className="space-y-1">
              {section.groups.map((group) => (
                <NavGroupAccordion
                  key={group.id}
                  title={group.title}
                  icon={group.icon}
                  open={openGroupId === group.id}
                  onToggle={() => toggleGroup(group.id)}
                >
                  <div className="space-y-1">
                    {group.items.map((item) => {
                      const active = pathname === item.href || (item.href !== `/${role.toLowerCase()}` && pathname.startsWith(item.href));
                      return (
                        <SidebarItem
                          key={item.href}
                          href={item.href}
                          label={item.label}
                          icon={item.icon ?? 'spark'}
                          active={active}
                          badge={item.badge}
                          onNavigate={onNavigate}
                        />
                      );
                    })}
                  </div>
                </NavGroupAccordion>
              ))}
            </div>
          </div>
        ))}
      </nav>
    </aside>
  );
}
