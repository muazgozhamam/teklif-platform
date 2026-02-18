import React from 'react';
import { Alert } from '@/src/ui/components/Alert';

export default function ErrorBanner({ message }: { message: string }) {
  return <Alert type="warning" message={message} className="mb-4" />;
}
