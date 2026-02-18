'use client';

import type { ReactNode } from 'react';
import { Badge } from '../components/Badge';
import { Button } from '../components/Button';
import { useTheme } from '../theme/ThemeProvider';

export default function Topbar({
  title,
  envLabel,
  onMenu,
  headerControls,
}: {
  title: string;
  envLabel: string;
  onMenu: () => void;
  headerControls?: ReactNode;
}) {
  const { setMode } = useTheme();
  return (
    <header className="sticky top-0 z-40 border-b border-[var(--border)] bg-[color-mix(in_srgb,var(--bg)_88%,transparent)] backdrop-blur">
      <div className="flex h-14 items-center justify-between gap-3 px-4 md:px-6">
        <div className="flex min-w-0 items-center gap-3">
          <button
            type="button"
            onClick={onMenu}
            data-interactive="true"
            className="ui-interactive inline-flex h-9 w-9 items-center justify-center rounded-lg border border-[var(--border)] text-[var(--muted)] hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)] hover:text-[var(--text)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)] md:hidden"
            aria-label="Menü"
          >
            ☰
          </button>
          <div className="truncate text-sm font-medium text-[var(--text)]">{title}</div>
        </div>

        <div className="flex min-w-0 items-center gap-2 md:gap-3">
          <Badge variant="neutral">{envLabel}</Badge>
          {headerControls ? <div className="hidden min-w-0 items-center md:flex">{headerControls}</div> : null}
          <Button variant="ghost" onClick={() => setMode('system')} className="h-8 px-3 text-xs md:h-9 md:text-sm">
            System
          </Button>
        </div>
      </div>
    </header>
  );
}
