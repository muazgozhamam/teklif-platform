'use client';

import { useEffect, useState } from 'react';

type ErrInfo = { type: 'error' | 'rejection'; message: string; stack?: string };

export default function ClientErrorOverlay() {
  const [err, setErr] = useState<ErrInfo | null>(null);

  useEffect(() => {
    const onError = (event: ErrorEvent) => {
      const message = event?.message || 'Unknown error';
      const stack = (event?.error && (event.error.stack || String(event.error))) || undefined;
      setErr({ type: 'error', message, stack });
    };

    const onRejection = (event: PromiseRejectionEvent) => {
      const reason: unknown = event.reason;
      const anyReason = (typeof reason === 'object' && reason !== null) ? (reason as Record<string, unknown>) : null;
      const message =
        typeof reason === 'string'
          ? reason
          : ((anyReason && typeof anyReason['message'] === 'string' ? (anyReason['message'] as string) : undefined) || (() => { try { return JSON.stringify(reason, null, 2); } catch { return String(reason); } })() || 'Unhandled promise rejection');
      const stack = anyReason && typeof anyReason['stack'] === 'string' ? String(anyReason['stack']) : undefined;
      setErr({ type: 'rejection', message, stack });
    };

    window.addEventListener('error', onError);
    window.addEventListener('unhandledrejection', onRejection);

    return () => {
      window.removeEventListener('error', onError);
      window.removeEventListener('unhandledrejection', onRejection);
    };
  }, []);

  if (!err) return null;

  return (
    <div
      style={{
        position: 'fixed',
        inset: 12,
        zIndex: 99999,
        background: 'rgba(15, 23, 42, 0.95)',
        color: '#fff',
        borderRadius: 12,
        padding: 14,
        fontFamily:
          'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace',
        overflow: 'auto',
        boxShadow: '0 10px 30px rgba(0,0,0,0.5)',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'center' }}>
        <div>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>Client Runtime Error ({err.type})</div>
          <div style={{ opacity: 0.95 }}>{err.message}</div>
        </div>
        <button
          onClick={() => setErr(null)}
          style={{
            border: '1px solid rgba(255,255,255,0.25)',
            padding: '8px 10px',
            borderRadius: 10,
            background: 'rgba(255,255,255,0.06)',
            color: '#fff',
            cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}
        >
          Close
        </button>
      </div>
      {err.stack ? (
        <pre style={{ marginTop: 12, fontSize: 12, lineHeight: 1.35, whiteSpace: 'pre-wrap' }}>{err.stack}</pre>
      ) : null}
      <div style={{ marginTop: 10, opacity: 0.8, fontSize: 12 }}>
        If this persists, paste the exact message above here.
      </div>
    </div>
  );
}
