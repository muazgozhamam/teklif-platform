'use client';

import React from 'react';
import { cn } from '../lib/cn';

type TabButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  active?: boolean;
};

export function TabButton({ active = false, className, ...props }: TabButtonProps) {
  return (
    <button
      type="button"
      data-active={active ? 'true' : 'false'}
      className={cn(
        'ui-interactive inline-flex h-9 items-center justify-center rounded-xl border px-3 text-sm font-medium',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
        active
          ? 'border-[var(--interactive-active-border)] bg-[var(--interactive-active-bg)] text-[var(--text)]'
          : 'border-[var(--border)] bg-[var(--card)] text-[var(--muted)] hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)] hover:text-[var(--text)]',
        className,
      )}
      {...props}
    />
  );
}
