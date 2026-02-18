import type * as React from 'react';
import { cn } from '../lib/cn';

export function Table({ className, ...props }: React.TableHTMLAttributes<HTMLTableElement>) {
  return <table className={cn('w-full text-sm', className)} {...props} />;
}

export function Th({ className, ...props }: React.ThHTMLAttributes<HTMLTableCellElement>) {
  return <th className={cn('bg-[var(--card-2)] px-3 py-2 text-left text-xs font-medium text-[var(--muted)]', className)} {...props} />;
}

export function Td({ className, ...props }: React.TdHTMLAttributes<HTMLTableCellElement>) {
  return <td className={cn('border-t border-[var(--border)] px-3 py-2 text-[var(--text)]', className)} {...props} />;
}
