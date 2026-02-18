'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '../lib/cn';
import type { NavSection, ShellRole } from './role-nav';
import { NavIcon } from './nav-icons';
import { roleLabelTr } from '@/lib/roles';
import Logo from '@/components/brand/Logo';

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
          <div key={section.title}>
            <div className="mb-2 px-2 text-[11px] uppercase tracking-[0.08em] text-[var(--muted)]">{section.title}</div>
            <div className="space-y-1">
              {section.items.map((item) => {
                const active = pathname === item.href || (item.href !== `/${role.toLowerCase()}` && pathname.startsWith(item.href));
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    data-active={active ? 'true' : 'false'}
                    onClick={onNavigate}
                    className={cn(
                      'ui-interactive group relative flex items-center gap-2 rounded-xl border px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
                      active
                        ? 'border-[var(--interactive-active-border)] bg-[var(--interactive-active-bg)] text-[var(--text)]'
                        : 'border-transparent text-[var(--muted)] hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)] hover:text-[var(--text)]',
                    )}
                  >
                    <span className={cn('absolute left-0 top-1/2 h-4 w-[2px] -translate-y-1/2 rounded-r', active ? 'bg-[var(--primary)]' : 'bg-transparent group-hover:bg-[var(--border-2)]')} />
                    <NavIcon name={item.icon ?? 'spark'} />
                    <span className="min-w-0 flex-1 truncate">{item.label}</span>
                    {item.badge ? (
                      <span className="rounded-full border border-[var(--border)] px-1.5 py-0.5 text-[10px] text-[var(--muted)]">{item.badge}</span>
                    ) : null}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>
    </aside>
  );
}
