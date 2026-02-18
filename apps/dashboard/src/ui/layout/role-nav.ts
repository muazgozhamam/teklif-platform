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
  title: string;
  items: NavItem[];
};

const roleSections: Record<ShellRole, NavSection[]> = {
  ADMIN: [
    {
      title: 'Operasyon',
      items: [
        { href: '/admin', label: 'Panel', icon: 'dashboard' },
        { href: '/admin/onboarding', label: 'Uyum Süreci', icon: 'clipboard-check' },
        { href: '/admin/audit', label: 'Denetim', icon: 'shield-check' },
      ],
    },
    {
      title: 'Yönetim',
      items: [
        { href: '/admin/users', label: 'Kullanıcılar', icon: 'users' },
        { href: '/admin/commission', label: 'Komisyon', icon: 'percent' },
      ],
    },
    {
      title: 'Araçlar',
      items: [{ href: '/admin/audit', label: 'Loglar / Raporlar', icon: 'file-text' }],
    },
  ],
  BROKER: [
    {
      title: 'Broker',
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
      title: 'Çalışma Alanı',
      items: [
        { href: '/consultant', label: 'Panel', icon: 'dashboard' },
        { href: '/consultant/inbox', label: 'Inbox / Talepler', icon: 'inbox' },
      ],
    },
    {
      title: 'İşlemler',
      items: [{ href: '/consultant/listings', label: 'İlanlar', icon: 'home' }],
    },
  ],
  HUNTER: [
    {
      title: 'Avcı',
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
  if (normalizedExtras.length === 0) return roleSections[role];

  const sections = roleSections[role].map((section) => ({
    ...section,
    items: [...section.items],
  }));

  const known = new Set<string>(sections.flatMap((section) => section.items.map((item) => item.href)));
  const extraItems = normalizedExtras.filter((item) => !known.has(item.href));

  if (extraItems.length > 0) {
    sections.push({
      title: 'Diğer',
      items: extraItems,
    });
  }

  return sections;
}
