import type { CSSProperties, ReactNode } from 'react';
import { cn } from '../lib/cn';

type BadgeVariant = 'neutral' | 'success' | 'warning' | 'danger' | 'primary';

const STYLES: Record<BadgeVariant, CSSProperties> = {
  neutral: { borderColor: 'var(--border)', background: 'var(--card-2)', color: 'var(--muted)' },
  success: { borderColor: 'color-mix(in srgb, var(--success) 40%, transparent)', background: 'color-mix(in srgb, var(--success) 16%, transparent)', color: 'var(--success)' },
  warning: { borderColor: 'color-mix(in srgb, var(--warning) 40%, transparent)', background: 'color-mix(in srgb, var(--warning) 16%, transparent)', color: 'var(--warning)' },
  danger: { borderColor: 'color-mix(in srgb, var(--danger) 40%, transparent)', background: 'color-mix(in srgb, var(--danger) 16%, transparent)', color: 'var(--danger)' },
  primary: { borderColor: 'color-mix(in srgb, var(--primary) 45%, transparent)', background: 'color-mix(in srgb, var(--primary) 16%, transparent)', color: 'var(--primary)' },
};

export function Badge({ children, variant = 'neutral', className }: { children: ReactNode; variant?: BadgeVariant; className?: string }) {
  return (
    <span className={cn('inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium', className)} style={STYLES[variant]}>
      {children}
    </span>
  );
}
