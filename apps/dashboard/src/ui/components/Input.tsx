'use client';

import React from 'react';
import { cn } from '../lib/cn';

export const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  function Input({ className, ...props }, ref) {
    return (
      <input
        ref={ref}
        className={cn(
          'ui-interactive h-10 w-full rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm text-[var(--text)] placeholder:text-[var(--muted)]',
          'hover:bg-[var(--interactive-hover-bg)] hover:border-[var(--interactive-hover-border)]',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
          className,
        )}
        {...props}
      />
    );
  },
);
