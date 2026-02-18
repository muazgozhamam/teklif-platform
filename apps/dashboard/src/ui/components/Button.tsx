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
        'inline-flex h-10 items-center justify-center rounded-xl border px-4 text-sm font-medium transition-colors',
        'focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[var(--primary)] focus-visible:ring-offset-1 focus-visible:ring-offset-[var(--bg)]',
        variant === 'primary' && 'border-transparent bg-[var(--primary)] text-white hover:opacity-95',
        variant === 'secondary' && 'border-[var(--border)] bg-[var(--card)] text-[var(--text)] hover:border-[var(--border-2)]',
        variant === 'danger' && 'border-transparent bg-[var(--danger)] text-white hover:opacity-95',
        variant === 'ghost' && 'border-transparent bg-transparent text-[var(--muted)] hover:bg-[var(--card-2)] hover:text-[var(--text)]',
        className,
      )}
      {...props}
    />
  );
}
