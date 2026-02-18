import type { CSSProperties } from 'react';
import { cn } from '../lib/cn';

type AlertType = 'error' | 'success' | 'info' | 'warning';

const STYLES: Record<AlertType, CSSProperties> = {
  info: { borderColor: 'var(--border)', background: 'var(--card-2)', color: 'var(--muted)' },
  error: { borderColor: 'color-mix(in srgb, var(--danger) 40%, transparent)', background: 'color-mix(in srgb, var(--danger) 10%, transparent)', color: 'var(--danger)' },
  success: { borderColor: 'color-mix(in srgb, var(--success) 40%, transparent)', background: 'color-mix(in srgb, var(--success) 10%, transparent)', color: 'var(--success)' },
  warning: { borderColor: 'color-mix(in srgb, var(--warning) 40%, transparent)', background: 'color-mix(in srgb, var(--warning) 10%, transparent)', color: 'var(--warning)' },
};

export function Alert({ type = 'info', message, className }: { type?: AlertType; message: string; className?: string }) {
  return (
    <div className={cn('rounded-xl border px-3 py-2 text-sm', className)} style={STYLES[type]} role="status">
      {message}
    </div>
  );
}
