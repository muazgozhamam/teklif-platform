'use client';

import React from 'react';
import { cn } from '../lib/cn';
import { NavIcon, type NavIconName } from './nav-icons';

type NavGroupAccordionProps = {
  title: string;
  open: boolean;
  onToggle: () => void;
  children: React.ReactNode;
  icon?: NavIconName;
};

export default function NavGroupAccordion({ title, open, onToggle, children, icon }: NavGroupAccordionProps) {
  return (
    <div>
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        className={cn(
          'ui-interactive flex w-full items-center justify-between rounded-md border border-transparent px-2 py-1.5 text-left',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
          'text-[11px] uppercase tracking-[0.08em] text-[var(--muted)] hover:bg-[var(--interactive-hover-bg)] hover:border-[var(--interactive-hover-border)]',
        )}
      >
        <span className="inline-flex items-center gap-1.5">
          {icon ? <NavIcon name={icon} className="h-3.5 w-3.5 opacity-70" /> : null}
          {title}
        </span>
        <NavIcon name={open ? 'chevron-down' : 'chevron-right'} className="h-3.5 w-3.5 opacity-70" />
      </button>

      <div
        className={cn(
          'grid overflow-hidden transition-[grid-template-rows,opacity] duration-200 ease-out',
          open ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0',
        )}
      >
        <div className="min-h-0 overflow-hidden pt-1">{children}</div>
      </div>
    </div>
  );
}
