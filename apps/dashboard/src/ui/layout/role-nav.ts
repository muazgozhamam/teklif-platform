import type { NavIconName } from './nav-icons';

export type ShellRole = 'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER';

export type NavItem = {
  href: string;
  label: string;
  icon?: NavIconName;
  roles?: ShellRole[];
  badge?: string;
};

export type NavSection = {
  id: string;
  title: string;
  defaultOpen?: boolean;
  items: NavItem[];
};

const roleSections: Record<ShellRole, NavSection[]> = {
  ADMIN: [
    {
      id: 'ops',
      title: 'Operasyon',
      defaultOpen: true,
      items: [
        { href: '/admin', label: 'Panel', icon: 'dashboard' },
        { href: '/admin/onboarding', label: 'Uyum Süreci', icon: 'clipboard-check' },
        { href: '/admin/audit', label: 'Denetim', icon: 'shield-check' },
      ],
    },
    {
      id: 'management',
      title: 'Yönetim',
      items: [
        { href: '/admin/users', label: 'Kullanıcılar', icon: 'users' },
        { href: '/admin/commission', label: 'Komisyon', icon: 'percent' },
      ],
    },
    {
      id: 'tools',
      title: 'Araçlar',
      items: [{ href: '/admin/audit', label: 'Loglar / Raporlar', icon: 'file-text' }],
    },
  ],
  BROKER: [
    {
      id: 'broker-core',
      title: 'Broker',
      defaultOpen: true,
      items: [
        { href: '/broker', label: 'Panel', icon: 'handshake' },
        { href: '/broker/leads/pending', label: 'Bekleyen Leadler', icon: 'list' },
        { href: '/broker/deals/new', label: 'Yeni Deal', icon: 'plus' },
        { href: '/broker/hunter-applications', label: 'İş Ortağı Başvuruları', icon: 'clipboard-check' },
      ],
    },
  ],
  CONSULTANT: [
    {
      id: 'workspace',
      title: 'Çalışma Alanı',
      defaultOpen: true,
      items: [
        { href: '/consultant', label: 'Panel', icon: 'dashboard' },
        { href: '/consultant/inbox', label: 'Inbox / Talepler', icon: 'inbox' },
      ],
    },
    {
      id: 'operations',
      title: 'İşlemler',
      items: [{ href: '/consultant/listings', label: 'İlanlar', icon: 'home' }],
    },
  ],
  HUNTER: [
    {
      id: 'hunter-core',
      title: 'Avcı',
      defaultOpen: true,
      items: [
        { href: '/hunter', label: 'Panel', icon: 'target' },
        { href: '/hunter/leads', label: 'Leadler', icon: 'list' },
        { href: '/hunter/leads/new', label: 'Yeni Lead', icon: 'plus' },
      ],
    },
  ],
};

export function getRoleNavSections(role: ShellRole, extra: NavItem[] = []): NavSection[] {
  const normalizedExtras = extra.map((item) => ({ ...item, icon: item.icon ?? 'spark' }));
  const sections = roleSections[role].map((section) => ({
    ...section,
    items: section.items.filter((item) => !item.roles || item.roles.includes(role)),
  }));
  const filteredSections = sections.filter((section) => section.items.length > 0);
  if (normalizedExtras.length === 0) return filteredSections;

  const known = new Set<string>(filteredSections.flatMap((section) => section.items.map((item) => item.href)));
  const extraItems = normalizedExtras.filter((item) => !known.has(item.href) && (!item.roles || item.roles.includes(role)));

  if (extraItems.length > 0) {
    filteredSections.push({
      id: 'other',
      title: 'Diğer',
      items: extraItems,
    });
  }

  return filteredSections;
}
