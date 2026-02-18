'use client';

import React from 'react';
import { cn } from '../lib/cn';

type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'destructive' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

export function Button({
  size = 'md',
  variant = 'secondary',
  loading = false,
  className,
  children,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; size?: ButtonSize; loading?: boolean }) {
  const normalizedVariant = variant === 'danger' ? 'destructive' : variant;
  return (
    <button
      className={cn(
        'ui-interactive inline-flex items-center justify-center gap-2 rounded-xl border font-medium',
        size === 'sm' && 'h-8 px-3 text-xs',
        size === 'md' && 'h-10 px-4 text-sm',
        size === 'lg' && 'h-11 px-5 text-sm',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
        normalizedVariant === 'primary' &&
          'border-transparent bg-[var(--accent)] text-[var(--accent-foreground)] hover:brightness-105 active:brightness-95',
        normalizedVariant === 'secondary' &&
          'border-[var(--border)] bg-[var(--card-2)] text-[var(--text)] hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)] active:border-[var(--interactive-active-border)] active:bg-[var(--interactive-active-bg)]',
        normalizedVariant === 'outline' &&
          'border-[var(--border)] bg-[var(--card)] text-[var(--text)] hover:bg-[var(--interactive-hover-bg)] hover:border-[var(--interactive-hover-border)] data-[active=true]:bg-[var(--interactive-active-bg)] data-[active=true]:border-[var(--interactive-active-border)]',
        normalizedVariant === 'destructive' &&
          'border-transparent bg-[var(--danger)] text-white hover:brightness-105 active:brightness-95',
        normalizedVariant === 'ghost' &&
          'border-transparent bg-transparent text-[var(--muted)] hover:bg-[var(--interactive-hover-bg)] hover:text-[var(--text)] data-[active=true]:bg-[var(--interactive-active-bg)] data-[active=true]:text-[var(--text)]',
        'disabled:opacity-50 disabled:pointer-events-none',
        className,
      )}
      disabled={loading || props.disabled}
      {...props}
    >
      {loading ? <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-r-transparent" aria-hidden="true" /> : null}
      {children}
    </button>
  );
}
