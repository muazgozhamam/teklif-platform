'use client';

import React from 'react';
import { cn } from '../lib/cn';

type InputProps = React.InputHTMLAttributes<HTMLInputElement> & {
  size?: 'sm' | 'md' | 'lg';
};

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  function Input({ className, size = 'md', ...props }, ref) {
    return (
      <input
        ref={ref}
        className={cn(
          'ui-interactive w-full rounded-xl border border-[var(--border)] bg-[var(--card)] text-[var(--text)] placeholder:text-[var(--muted)]',
          size === 'sm' && 'h-8 px-2.5 text-xs',
          size === 'md' && 'h-10 px-3 text-sm',
          size === 'lg' && 'h-11 px-3.5 text-sm',
          'hover:bg-[var(--interactive-hover-bg)] hover:border-[var(--interactive-hover-border)]',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)] focus-visible:border-[var(--interactive-active-border)]',
          className,
        )}
        {...props}
      />
    );
  },
);
