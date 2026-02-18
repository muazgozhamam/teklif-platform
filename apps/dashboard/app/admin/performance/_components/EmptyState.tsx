import React from 'react';
import { Card } from '@/src/ui/components/Card';

export default function EmptyState({ title, note }: { title: string; note?: string }) {
  return (
    <Card className="mt-4 border-dashed">
      <div className="text-sm font-medium text-[var(--text)]">{title}</div>
      {note ? <div className="mt-1 text-xs text-[var(--muted)]">{note}</div> : null}
    </Card>
  );
}
