'use client';

import Link from 'next/link';
import { cn } from '../lib/cn';
import { NavIcon, type NavIconName } from './nav-icons';

type SidebarItemProps = {
  href: string;
  label: string;
  icon?: NavIconName;
  active?: boolean;
  badge?: string;
  onNavigate?: () => void;
};

export default function SidebarItem({ href, label, icon = 'spark', active = false, badge, onNavigate }: SidebarItemProps) {
  return (
    <Link
      href={href}
      data-active={active ? 'true' : 'false'}
      onClick={onNavigate}
      className={cn(
        'ui-interactive group relative flex items-center gap-2 rounded-xl border px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
        active
          ? 'border-[var(--interactive-active-border)] bg-[var(--interactive-active-bg)] text-[var(--text)]'
          : 'border-transparent text-[var(--muted)] hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)] hover:text-[var(--text)]',
      )}
    >
      <span
        className={cn(
          'absolute left-0 top-1/2 h-4 w-[2px] -translate-y-1/2 rounded-r',
          active ? 'bg-[var(--primary)]' : 'bg-transparent group-hover:bg-[var(--border-2)]',
        )}
      />
      <NavIcon name={icon} />
      <span className="min-w-0 flex-1 truncate">{label}</span>
      {badge ? <span className="rounded-full border border-[var(--border)] px-1.5 py-0.5 text-[10px] text-[var(--muted)]">{badge}</span> : null}
    </Link>
  );
}
