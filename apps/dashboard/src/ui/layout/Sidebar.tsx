'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '../lib/cn';
import type { NavItem, ShellRole } from './role-nav';
import { roleLabelTr } from '@/lib/roles';

export default function Sidebar({ role, nav, mobileOpen, onNavigate }: { role: ShellRole; nav: NavItem[]; mobileOpen: boolean; onNavigate: () => void }) {
  const pathname = usePathname();
  return (
    <aside
      className={cn(
        'fixed inset-y-0 left-0 z-50 w-[240px] border-r border-[var(--border)] bg-[var(--sidebar)] p-3 transition-transform md:static md:translate-x-0',
        mobileOpen ? 'translate-x-0' : '-translate-x-full',
      )}
    >
      <div className="mb-4 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2">
        <div className="text-[11px] uppercase tracking-[0.08em] text-[var(--muted)]">Rol</div>
        <div className="mt-1 text-sm font-medium text-[var(--text)]">{roleLabelTr(role)}</div>
      </div>

      <div className="mb-2 px-2 text-[11px] uppercase tracking-[0.08em] text-[var(--muted)]">Navigasyon</div>
      <nav className="space-y-1">
        {nav.map((item) => {
          const active = pathname === item.href || (item.href !== `/${role.toLowerCase()}` && pathname.startsWith(item.href));
          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={onNavigate}
              className={cn(
                'group relative block rounded-xl border px-3 py-2 text-sm transition-colors',
                active
                  ? 'border-[var(--border-2)] bg-[var(--card)] text-[var(--text)]'
                  : 'border-transparent text-[var(--muted)] hover:border-[var(--border)] hover:bg-[var(--card-2)] hover:text-[var(--text)]',
              )}
            >
              <span className={cn('absolute left-0 top-1/2 h-4 w-[2px] -translate-y-1/2 rounded-r', active ? 'bg-[var(--primary)]' : 'bg-transparent group-hover:bg-[var(--border-2)]')} />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
