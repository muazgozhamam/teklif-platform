'use client';

import React from 'react';
import { cn } from '../lib/cn';

type SelectProps = React.SelectHTMLAttributes<HTMLSelectElement> & {
  uiSize?: 'sm' | 'md' | 'lg';
};

export const Select = React.forwardRef<HTMLSelectElement, SelectProps>(function Select(
  { className, uiSize = 'md', children, ...props },
  ref,
) {
  return (
    <select
      ref={ref}
      className={cn(
        'ui-interactive w-full rounded-xl border border-[var(--border)] bg-[var(--card)] text-[var(--text)]',
        'hover:bg-[var(--interactive-hover-bg)] hover:border-[var(--interactive-hover-border)]',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)] focus-visible:border-[var(--interactive-active-border)]',
        uiSize === 'sm' && 'h-8 px-2.5 text-xs',
        uiSize === 'md' && 'h-10 px-3 text-sm',
        uiSize === 'lg' && 'h-11 px-3.5 text-sm',
        className,
      )}
      {...props}
    >
      {children}
    </select>
  );
});
