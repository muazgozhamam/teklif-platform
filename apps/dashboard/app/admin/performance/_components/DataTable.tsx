'use client';

import React from 'react';
import { Card } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';

type Column<Row extends Record<string, unknown>> = {
  key: keyof Row;
  label: string;
  sortable?: boolean;
  render?: (row: Row) => React.ReactNode;
};

export default function DataTable<Row extends Record<string, unknown>>({
  title,
  rows,
  columns,
  searchPlaceholder = 'Ara...',
  onRowClick,
}: {
  title?: string;
  rows: Row[];
  columns: Column<Row>[];
  searchPlaceholder?: string;
  onRowClick?: (row: Row) => void;
}) {
  const [q, setQ] = React.useState('');
  const [sortKey, setSortKey] = React.useState<keyof Row | null>(null);
  const [sortDir, setSortDir] = React.useState<'asc' | 'desc'>('desc');

  const filtered = React.useMemo(() => {
    const needle = q.trim().toLowerCase();
    let list = rows;
    if (needle) {
      list = list.filter((row) => Object.values(row).join(' ').toLowerCase().includes(needle));
    }
    if (!sortKey) return list;

    return [...list].sort((a, b) => {
      const av = a[sortKey];
      const bv = b[sortKey];
      const an = typeof av === 'number' ? av : Number(av);
      const bn = typeof bv === 'number' ? bv : Number(bv);
      if (!Number.isNaN(an) && !Number.isNaN(bn)) return sortDir === 'asc' ? an - bn : bn - an;
      const as = String(av ?? '');
      const bs = String(bv ?? '');
      return sortDir === 'asc' ? as.localeCompare(bs, 'tr') : bs.localeCompare(as, 'tr');
    });
  }, [q, rows, sortKey, sortDir]);

  function toggleSort(key: keyof Row) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
      return;
    }
    setSortKey(key);
    setSortDir('desc');
  }

  return (
    <Card className="mt-4 overflow-hidden p-0">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border)] px-4 py-3">
        <div className="text-sm font-medium text-[var(--text)]">{title || 'Tablo'}</div>
        <div className="w-full sm:w-72">
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={searchPlaceholder} />
        </div>
      </div>
      <div className="overflow-auto">
        <table className="min-w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--border)] bg-[var(--card-2)] text-left text-xs text-[var(--muted)]">
              {columns.map((col) => (
                <th key={String(col.key)} className="px-4 py-2 font-medium">
                  {col.sortable ? (
                    <button
                      type="button"
                      className="ui-interactive rounded px-1 py-0.5"
                      onClick={() => toggleSort(col.key)}
                    >
                      {col.label}
                    </button>
                  ) : (
                    col.label
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map((row, idx) => (
              <tr
                key={idx}
                className="border-b border-[var(--border)] text-[var(--text)] hover:bg-[var(--interactive-hover-bg)]"
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                role={onRowClick ? 'button' : undefined}
                tabIndex={onRowClick ? 0 : -1}
              >
                {columns.map((col) => (
                  <td key={String(col.key)} className="px-4 py-2 align-top">
                    {col.render ? col.render(row) : String(row[col.key] ?? '-')}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
