import React from 'react';
import { Card } from '@/src/ui/components/Card';

export type KpiCardItem = {
  label: string;
  value: string;
  hint?: string;
};

export default function KpiCardsGrid({ items }: { items: KpiCardItem[] }) {
  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
      {items.map((item) => (
        <Card key={item.label} className="p-4">
          <div className="text-xs text-[var(--muted)]">{item.label}</div>
          <div className="mt-1 text-[clamp(22px,5vw,28px)] font-semibold leading-none text-[var(--text)]">{item.value}</div>
          {item.hint ? <div className="mt-1 text-xs text-[var(--muted-2)]">{item.hint}</div> : null}
        </Card>
      ))}
    </div>
  );
}
