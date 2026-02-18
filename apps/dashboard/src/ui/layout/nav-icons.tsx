import React from 'react';
import { cn } from '../lib/cn';

export type NavIconName =
  | 'dashboard'
  | 'clipboard-check'
  | 'shield-check'
  | 'users'
  | 'percent'
  | 'file-text'
  | 'settings'
  | 'inbox'
  | 'briefcase'
  | 'home'
  | 'target'
  | 'handshake'
  | 'plus'
  | 'list'
  | 'spark'
  | 'chevron-right'
  | 'chevron-down';

type IconProps = { className?: string };

function BaseIcon({ className, children }: React.PropsWithChildren<IconProps>) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={cn('h-4 w-4 opacity-80', className)}
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

const ICONS: Record<NavIconName, React.ComponentType<IconProps>> = {
  dashboard: (p) => (
    <BaseIcon {...p}>
      <rect x="3" y="3" width="8" height="8" rx="2" />
      <rect x="13" y="3" width="8" height="5" rx="2" />
      <rect x="13" y="10" width="8" height="11" rx="2" />
      <rect x="3" y="13" width="8" height="8" rx="2" />
    </BaseIcon>
  ),
  'clipboard-check': (p) => (
    <BaseIcon {...p}>
      <rect x="5" y="4" width="14" height="17" rx="2" />
      <path d="M9 4.5h6" />
      <path d="m9 13 2 2 4-4" />
    </BaseIcon>
  ),
  'shield-check': (p) => (
    <BaseIcon {...p}>
      <path d="M12 3 5 6v6c0 4.2 2.4 6.9 7 9 4.6-2.1 7-4.8 7-9V6l-7-3Z" />
      <path d="m9.5 12.5 1.8 1.8 3.8-3.8" />
    </BaseIcon>
  ),
  users: (p) => (
    <BaseIcon {...p}>
      <circle cx="9" cy="8" r="3" />
      <circle cx="17" cy="10" r="2.5" />
      <path d="M3.5 19c.8-2.5 2.7-4 5.5-4s4.7 1.5 5.5 4" />
      <path d="M14.5 19c.4-1.7 1.6-2.8 3.5-3.3" />
    </BaseIcon>
  ),
  percent: (p) => (
    <BaseIcon {...p}>
      <line x1="19" y1="5" x2="5" y2="19" />
      <circle cx="7" cy="7" r="2" />
      <circle cx="17" cy="17" r="2" />
    </BaseIcon>
  ),
  'file-text': (p) => (
    <BaseIcon {...p}>
      <path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8l-5-5Z" />
      <path d="M14 3v5h5" />
      <path d="M9 13h6M9 17h6" />
    </BaseIcon>
  ),
  settings: (p) => (
    <BaseIcon {...p}>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1 1 0 0 0 .2 1.1l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1 1 0 0 0-1.1-.2 1 1 0 0 0-.6.9V20a2 2 0 1 1-4 0v-.1a1 1 0 0 0-.6-.9 1 1 0 0 0-1.1.2l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1 1 0 0 0 .2-1.1 1 1 0 0 0-.9-.6H4a2 2 0 1 1 0-4h.1a1 1 0 0 0 .9-.6 1 1 0 0 0-.2-1.1l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1 1 0 0 0 1.1.2H9a1 1 0 0 0 .6-.9V4a2 2 0 1 1 4 0v.1a1 1 0 0 0 .6.9h.1a1 1 0 0 0 1.1-.2l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1 1 0 0 0-.2 1.1V9c0 .4.2.8.6.9H20a2 2 0 1 1 0 4h-.1a1 1 0 0 0-.9.6Z" />
    </BaseIcon>
  ),
  inbox: (p) => (
    <BaseIcon {...p}>
      <path d="M3 13V6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v7" />
      <path d="M3 13h5l2 3h4l2-3h5" />
      <path d="M5 13v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5" />
    </BaseIcon>
  ),
  briefcase: (p) => (
    <BaseIcon {...p}>
      <rect x="3" y="7" width="18" height="13" rx="2" />
      <path d="M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
      <path d="M3 12h18" />
    </BaseIcon>
  ),
  home: (p) => (
    <BaseIcon {...p}>
      <path d="M3 11 12 4l9 7" />
      <path d="M5 10v10h14V10" />
    </BaseIcon>
  ),
  target: (p) => (
    <BaseIcon {...p}>
      <circle cx="12" cy="12" r="8" />
      <circle cx="12" cy="12" r="4" />
      <circle cx="12" cy="12" r="1" />
    </BaseIcon>
  ),
  handshake: (p) => (
    <BaseIcon {...p}>
      <path d="M8 12 4 8l3-3 4 4" />
      <path d="m16 12 4-4-3-3-4 4" />
      <path d="m8 12 3 3a2 2 0 0 0 2.8 0l2.2-2.2" />
      <path d="m10 14 1.2 1.2M12 13l1.2 1.2" />
    </BaseIcon>
  ),
  plus: (p) => (
    <BaseIcon {...p}>
      <path d="M12 5v14M5 12h14" />
    </BaseIcon>
  ),
  list: (p) => (
    <BaseIcon {...p}>
      <path d="M8 6h13M8 12h13M8 18h13" />
      <circle cx="4" cy="6" r="1" />
      <circle cx="4" cy="12" r="1" />
      <circle cx="4" cy="18" r="1" />
    </BaseIcon>
  ),
  spark: (p) => (
    <BaseIcon {...p}>
      <path d="m12 3 1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8L12 3Z" />
    </BaseIcon>
  ),
  'chevron-right': (p) => (
    <BaseIcon {...p}>
      <path d="m9 6 6 6-6 6" />
    </BaseIcon>
  ),
  'chevron-down': (p) => (
    <BaseIcon {...p}>
      <path d="m6 9 6 6 6-6" />
    </BaseIcon>
  ),
};

export function NavIcon({ name, className }: { name: NavIconName; className?: string }) {
  const Component = ICONS[name] ?? ICONS.spark;
  return <Component className={className} />;
}
