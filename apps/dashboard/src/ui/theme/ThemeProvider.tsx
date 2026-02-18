'use client';

import React from 'react';

type ThemeMode = 'system' | 'light' | 'dark';

type ThemeContextValue = {
  mode: ThemeMode;
  setMode: (mode: ThemeMode) => void;
  resolved: 'light' | 'dark';
};

const ThemeContext = React.createContext<ThemeContextValue | null>(null);

function systemPrefersDark() {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return true;
  return window.matchMedia('(prefers-color-scheme: dark)').matches;
}

function resolveTheme(mode: ThemeMode): 'light' | 'dark' {
  if (mode === 'light') return 'light';
  if (mode === 'dark') return 'dark';
  return systemPrefersDark() ? 'dark' : 'light';
}

export default function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [mode, setModeState] = React.useState<ThemeMode>('system');
  const [resolved, setResolved] = React.useState<'light' | 'dark'>('dark');

  const apply = React.useCallback((nextMode: ThemeMode) => {
    const nextResolved = resolveTheme(nextMode);
    document.documentElement.setAttribute('data-theme', nextResolved);
    setResolved(nextResolved);
  }, []);

  React.useEffect(() => {
    const stored = window.localStorage.getItem('satdedi-theme-mode') as ThemeMode | null;
    const initial = stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system';
    setModeState(initial);
    apply(initial);
  }, [apply]);

  React.useEffect(() => {
    if (mode !== 'system') return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = () => apply('system');
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, [mode, apply]);

  const setMode = React.useCallback(
    (nextMode: ThemeMode) => {
      setModeState(nextMode);
      window.localStorage.setItem('satdedi-theme-mode', nextMode);
      apply(nextMode);
    },
    [apply],
  );

  const value = React.useMemo(() => ({ mode, setMode, resolved }), [mode, setMode, resolved]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = React.useContext(ThemeContext);
  if (!ctx) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return ctx;
}
