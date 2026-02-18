'use client';

import React from 'react';
import { cn } from '../lib/cn';

type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost';

export function Button({
  variant = 'secondary',
  className,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant }) {
  return (
    <button
      className={cn(
        'ui-interactive inline-flex h-10 items-center justify-center rounded-xl border px-4 text-sm font-medium',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
        variant === 'primary' &&
          'border-transparent bg-[var(--primary)] text-white hover:bg-[color-mix(in_srgb,var(--primary)_92%,black)] data-[active=true]:bg-[color-mix(in_srgb,var(--primary)_85%,black)]',
        variant === 'secondary' &&
          'border-[var(--border)] bg-[var(--card)] text-[var(--text)] hover:bg-[var(--interactive-hover-bg)] hover:border-[var(--interactive-hover-border)] data-[active=true]:bg-[var(--interactive-active-bg)] data-[active=true]:border-[var(--interactive-active-border)]',
        variant === 'danger' &&
          'border-transparent bg-[var(--danger)] text-white hover:bg-[color-mix(in_srgb,var(--danger)_90%,black)] data-[active=true]:bg-[color-mix(in_srgb,var(--danger)_82%,black)]',
        variant === 'ghost' &&
          'border-transparent bg-transparent text-[var(--muted)] hover:bg-[var(--interactive-hover-bg)] hover:text-[var(--text)] data-[active=true]:bg-[var(--interactive-active-bg)] data-[active=true]:text-[var(--text)]',
        'disabled:opacity-50 disabled:pointer-events-none',
        className,
      )}
      {...props}
    />
  );
}
