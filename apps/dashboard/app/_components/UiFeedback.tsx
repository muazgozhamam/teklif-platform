'use client';

import React from 'react';
import { Alert } from '@/src/ui/components/Alert';

type NoticeType = 'error' | 'success' | 'info';

export function AlertMessage({ type, message }: { type: NoticeType; message: string }) {
  return <Alert type={type} message={message} className="mt-3" />;
}

export function useToast() {
  const [toast, setToast] = React.useState<{ type: NoticeType; message: string } | null>(null);

  const show = React.useCallback((type: NoticeType, message: string, ms = 2600) => {
    setToast({ type, message });
    window.setTimeout(() => setToast(null), ms);
  }, []);

  return { toast, show };
}

export function ToastView({ toast }: { toast: { type: NoticeType; message: string } | null }) {
  if (!toast) return null;
  return (
    <div className="fixed bottom-4 right-4 z-50 min-w-56 max-w-[420px]">
      <Alert type={toast.type} message={toast.message} />
    </div>
  );
}
