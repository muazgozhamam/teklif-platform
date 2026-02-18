'use client';

import React from 'react';
import { cn } from '../lib/cn';

type DropdownItemProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  active?: boolean;
};

export function DropdownItem({ active = false, className, ...props }: DropdownItemProps) {
  return (
    <button
      type="button"
      data-active={active ? 'true' : 'false'}
      className={cn(
        'ui-interactive flex w-full items-center rounded-lg border border-transparent px-3 py-2 text-left text-sm',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]',
        active
          ? 'border-[var(--interactive-active-border)] bg-[var(--interactive-active-bg)] text-[var(--text)]'
          : 'text-[var(--muted)] hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)] hover:text-[var(--text)]',
        className,
      )}
      {...props}
    />
  );
}
