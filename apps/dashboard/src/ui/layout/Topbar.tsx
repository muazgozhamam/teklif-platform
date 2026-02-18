'use client';

import Link from 'next/link';
import Logo from '@/components/brand/Logo';
import { Badge } from '../components/Badge';
import { Button } from '../components/Button';
import { useTheme } from '../theme/ThemeProvider';

export default function Topbar({ title, envLabel, onMenu }: { title: string; envLabel: string; onMenu: () => void }) {
  const { mode, setMode } = useTheme();
  return (
    <header className="sticky top-0 z-40 border-b border-[var(--border)] bg-[color-mix(in_srgb,var(--bg)_88%,transparent)] backdrop-blur">
      <div className="flex h-14 items-center justify-between gap-3 px-4 md:px-6">
        <div className="flex items-center gap-3">
          <button type="button" onClick={onMenu} className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-[var(--border)] text-[var(--muted)] md:hidden" aria-label="Menü">
            ☰
          </button>
          <Link href="/" className="hidden md:inline-flex"><Logo size="md" /></Link>
          <div className="hidden h-5 w-px bg-[var(--border)] md:block" />
          <div className="text-sm font-medium text-[var(--text)]">{title}</div>
        </div>

        <div className="flex items-center gap-2">
          <Badge variant="neutral">{envLabel}</Badge>
          <div className="hidden md:flex">
            <Button
              variant="ghost"
              onClick={() => setMode(mode === 'dark' ? 'light' : mode === 'light' ? 'system' : 'dark')}
              title={`Tema: ${mode}`}
            >
              {mode === 'dark' ? 'Dark' : mode === 'light' ? 'Light' : 'System'}
            </Button>
          </div>
        </div>
      </div>
    </header>
  );
}
