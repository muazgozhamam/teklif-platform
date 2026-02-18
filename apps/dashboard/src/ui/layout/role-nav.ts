import type { NavIconName } from './nav-icons';

export type ShellRole = 'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER';

export type NavItem = {
  href: string;
  label: string;
  icon?: NavIconName;
  roles?: ShellRole[];
  badge?: string;
};

export type NavGroup = {
  id: string;
  title: string;
  icon?: NavIconName;
  defaultOpen?: boolean;
  items: NavItem[];
};

export type NavSection = {
  id: string;
  title: string;
  groups: NavGroup[];
};

const roleSections: Record<ShellRole, NavSection[]> = {
  ADMIN: [
    {
      id: 'operations',
      title: 'Operasyon',
      groups: [
        {
          id: 'command',
          title: 'Komuta',
          icon: 'dashboard',
          defaultOpen: true,
          items: [
            { href: '/admin', label: 'Genel Bakış', icon: 'dashboard' },
            { href: '/admin/onboarding', label: 'Uyum Süreci', icon: 'clipboard-check' },
            { href: '/admin/audit', label: 'Denetim', icon: 'shield-check' },
          ],
        },
      ],
    },
    {
      id: 'management',
      title: 'Yönetim',
      groups: [
        {
          id: 'users-and-config',
          title: 'Kullanıcı ve Ayarlar',
          icon: 'users',
          defaultOpen: true,
          items: [
            { href: '/admin/users', label: 'Kullanıcılar', icon: 'users' },
            { href: '/admin/commission/policies', label: 'Komisyon', icon: 'percent' },
          ],
        },
      ],
    },
    {
      id: 'commission',
      title: 'Hakediş',
      groups: [
        {
          id: 'commission-admin',
          title: 'Hakediş Operasyonu',
          icon: 'percent',
          defaultOpen: true,
          items: [
            { href: '/admin/commission', label: 'Genel Bakış', icon: 'dashboard' },
            { href: '/admin/commission/pending', label: 'Onay Kuyruğu', icon: 'clipboard-check' },
            { href: '/admin/commission/payouts', label: 'Ödemeler', icon: 'handshake' },
            { href: '/admin/commission/disputes', label: 'Uyuşmazlıklar', icon: 'shield-check' },
            { href: '/admin/commission/period-locks', label: 'Dönem Kilidi', icon: 'settings' },
          ],
        },
      ],
    },
    {
      id: 'performance',
      title: 'Performans',
      groups: [
        {
          id: 'perf-overview',
          title: 'Genel',
          icon: 'dashboard',
          defaultOpen: true,
          items: [{ href: '/admin/performance/overview', label: 'Genel Bakış', icon: 'dashboard' }],
        },
        {
          id: 'perf-funnel',
          title: 'Funnel',
          icon: 'spark',
          defaultOpen: true,
          items: [
            { href: '/admin/performance/funnel/ref-to-portfolio', label: 'Referans → Portföy', icon: 'list' },
            { href: '/admin/performance/funnel/portfolio-to-sale', label: 'Portföy → Satış', icon: 'handshake' },
          ],
        },
        {
          id: 'perf-leaderboard',
          title: 'Liderlik',
          icon: 'users',
          items: [
            { href: '/admin/performance/leaderboard/consultants', label: 'Danışmanlar', icon: 'briefcase' },
            { href: '/admin/performance/leaderboard/partners', label: 'İş Ortakları', icon: 'target' },
          ],
        },
        {
          id: 'perf-finance',
          title: 'Finans',
          icon: 'percent',
          items: [
            { href: '/admin/performance/finance/revenue', label: 'Ciro', icon: 'file-text' },
            { href: '/admin/performance/finance/commission', label: 'Komisyon', icon: 'percent' },
          ],
        },
      ],
    },
    {
      id: 'applications',
      title: 'Aday & Talepler',
      groups: [
        {
          id: 'applications-core',
          title: 'CRM',
          icon: 'inbox',
          defaultOpen: true,
          items: [
            { href: '/admin/applications', label: 'Genel Bakış', icon: 'dashboard' },
            { href: '/admin/applications/pool', label: 'Aday Havuzu', icon: 'list' },
            { href: '/admin/applications/customers', label: 'Müşteri Adayları', icon: 'users' },
            { href: '/admin/applications/portfolio', label: 'Portföy Adayları', icon: 'home' },
            { href: '/admin/applications/consultants', label: 'Danışman Adayları', icon: 'briefcase' },
            { href: '/admin/applications/hunters', label: 'Hunter Adayları', icon: 'target' },
            { href: '/admin/applications/brokers', label: 'Broker Adayları', icon: 'handshake' },
            { href: '/admin/applications/partners', label: 'İş Ortağı Adayları', icon: 'users' },
            { href: '/admin/applications/corporate', label: 'Kurumsal Talepler', icon: 'file-text' },
            { href: '/admin/applications/support', label: 'Destek / Şikayet', icon: 'shield-check' },
          ],
        },
      ],
    },
    {
      id: 'leaderboards',
      title: 'Performans Sıralama',
      groups: [
        {
          id: 'leaderboards-core',
          title: 'Sıralamalar',
          icon: 'spark',
          defaultOpen: true,
          items: [
            { href: '/admin/leaderboards', label: 'Genel', icon: 'dashboard' },
            { href: '/admin/leaderboards/hunter', label: 'Hunter Sıralama', icon: 'target' },
            { href: '/admin/leaderboards/consultant', label: 'Danışman Sıralama', icon: 'briefcase' },
            { href: '/admin/leaderboards/broker', label: 'Broker Sıralama', icon: 'handshake' },
          ],
        },
      ],
    },
  ],
  BROKER: [
    {
      id: 'broker-core',
      title: 'Broker',
      groups: [
        {
          id: 'broker-work',
          title: 'Çalışma Alanı',
          icon: 'handshake',
          defaultOpen: true,
          items: [
            { href: '/broker', label: 'Panel', icon: 'handshake' },
            { href: '/broker/leads/pending', label: 'Bekleyen Leadler', icon: 'list' },
            { href: '/broker/deals/new', label: 'Yeni Deal', icon: 'plus' },
            { href: '/broker/hunter-applications', label: 'İş Ortağı Başvuruları', icon: 'clipboard-check' },
          ],
        },
      ],
    },
    {
      id: 'broker-commission',
      title: 'Hakediş',
      groups: [
        {
          id: 'broker-commission-ops',
          title: 'Onay',
          icon: 'percent',
          defaultOpen: true,
          items: [{ href: '/broker/commission/approval', label: 'Bekleyen Onaylar', icon: 'clipboard-check' }],
        },
      ],
    },
    {
      id: 'broker-account',
      title: 'Hesap',
      groups: [
        {
          id: 'broker-account-settings',
          title: 'Ayarlar',
          icon: 'settings',
          items: [{ href: '/broker', label: 'Profil / Ayarlar', icon: 'settings' }],
        },
      ],
    },
  ],
  CONSULTANT: [
    {
      id: 'workspace',
      title: 'Çalışma Alanı',
      groups: [
        {
          id: 'consultant-inbox',
          title: 'Operasyon',
          icon: 'inbox',
          defaultOpen: true,
          items: [
            { href: '/consultant', label: 'Panel', icon: 'dashboard' },
            { href: '/consultant/inbox', label: 'Inbox / Talepler', icon: 'inbox' },
          ],
        },
      ],
    },
    {
      id: 'operations',
      title: 'İşlemler',
      groups: [
        {
          id: 'consultant-listings',
          title: 'Portföy',
          icon: 'home',
          defaultOpen: true,
          items: [{ href: '/consultant/listings', label: 'İlanlar', icon: 'home' }],
        },
      ],
    },
    {
      id: 'consultant-commission',
      title: 'Hakediş',
      groups: [
        {
          id: 'consultant-commission-my',
          title: 'Kazanç',
          icon: 'percent',
          defaultOpen: true,
          items: [{ href: '/consultant/commission', label: 'Hakedişim', icon: 'percent' }],
        },
      ],
    },
    {
      id: 'consultant-account',
      title: 'Hesap',
      groups: [
        {
          id: 'consultant-account-settings',
          title: 'Ayarlar',
          icon: 'settings',
          items: [{ href: '/consultant', label: 'Profil / Ayarlar', icon: 'settings' }],
        },
      ],
    },
  ],
  HUNTER: [
    {
      id: 'hunter-core',
      title: 'Avcı',
      groups: [
        {
          id: 'hunter-leads',
          title: 'Lead Yönetimi',
          icon: 'target',
          defaultOpen: true,
          items: [
            { href: '/hunter', label: 'Panel', icon: 'target' },
            { href: '/hunter/leads', label: 'Leadler', icon: 'list' },
            { href: '/hunter/leads/new', label: 'Yeni Lead', icon: 'plus' },
          ],
        },
      ],
    },
    {
      id: 'hunter-commission',
      title: 'Hakediş',
      groups: [
        {
          id: 'hunter-commission-my',
          title: 'Kazanç',
          icon: 'percent',
          defaultOpen: true,
          items: [{ href: '/hunter/commission', label: 'Hakedişim', icon: 'percent' }],
        },
      ],
    },
    {
      id: 'hunter-account',
      title: 'Hesap',
      groups: [
        {
          id: 'hunter-account-settings',
          title: 'Ayarlar',
          icon: 'settings',
          items: [{ href: '/hunter', label: 'Profil / Ayarlar', icon: 'settings' }],
        },
      ],
    },
  ],
};

export function getRoleNavSections(role: ShellRole, extra: NavItem[] = []): NavSection[] {
  const normalizedExtras = extra.map((item) => ({ ...item, icon: item.icon ?? 'spark' }));
  const sections = roleSections[role].map((section) => ({
    ...section,
    groups: section.groups
      .map((group) => ({
        ...group,
        items: group.items.filter((item) => !item.roles || item.roles.includes(role)),
      }))
      .filter((group) => group.items.length > 0),
  }));
  const filteredSections = sections.filter((section) => section.groups.length > 0);
  if (normalizedExtras.length === 0) return filteredSections;

  const known = new Set<string>(
    filteredSections.flatMap((section) => section.groups.flatMap((group) => group.items.map((item) => item.href))),
  );
  const extraItems = normalizedExtras.filter((item) => !known.has(item.href) && (!item.roles || item.roles.includes(role)));

  if (extraItems.length > 0) {
    filteredSections.push({
      id: 'other',
      title: 'Diğer',
      groups: [
        {
          id: 'other-links',
          title: 'Kısayollar',
          defaultOpen: true,
          items: extraItems,
        },
      ],
    });
  }

  return filteredSections;
}
