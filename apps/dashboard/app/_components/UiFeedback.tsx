'use client';

import React from 'react';

export function AlertMessage({
  type,
  message,
}: {
  type: 'error' | 'success' | 'info';
  message: string;
}) {
  const styleByType: Record<string, React.CSSProperties> = {
    error: { border: '1px solid #fecaca', background: '#fef2f2', color: '#991b1b' },
    success: { border: '1px solid #bbf7d0', background: '#f0fdf4', color: '#166534' },
    info: { border: '1px solid #bfdbfe', background: '#eff6ff', color: '#1e3a8a' },
  };

  return (
    <div style={{ marginTop: 12, padding: 12, borderRadius: 12, fontSize: 13, fontWeight: 700, ...styleByType[type] }}>
      {message}
    </div>
  );
}

export function useToast() {
  const [toast, setToast] = React.useState<{ type: 'error' | 'success' | 'info'; message: string } | null>(null);

  const show = React.useCallback((type: 'error' | 'success' | 'info', message: string, ms = 2600) => {
    setToast({ type, message });
    window.setTimeout(() => setToast(null), ms);
  }, []);

  return { toast, show };
}

export function ToastView({ toast }: { toast: { type: 'error' | 'success' | 'info'; message: string } | null }) {
  if (!toast) return null;
  return (
    <div style={{ position: 'fixed', right: 14, bottom: 14, zIndex: 50, minWidth: 240, maxWidth: 420 }}>
      <AlertMessage type={toast.type} message={toast.message} />
    </div>
  );
}
