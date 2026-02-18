export type ShellRole = 'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER';

export type NavItem = {
  href: string;
  label: string;
};

const baseRoleNav: Record<ShellRole, NavItem[]> = {
  ADMIN: [
    { href: '/admin', label: 'Panel' },
    { href: '/admin/users', label: 'Kullanıcılar' },
    { href: '/admin/onboarding', label: 'Uyum Süreci' },
    { href: '/admin/audit', label: 'Denetim' },
    { href: '/admin/commission', label: 'Komisyon' },
  ],
  BROKER: [
    { href: '/broker', label: 'Panel' },
    { href: '/broker/leads/pending', label: 'Bekleyen Leadler' },
    { href: '/broker/deals/new', label: 'Yeni Deal' },
    { href: '/broker/hunter-applications', label: 'İş Ortağı Başvuruları' },
  ],
  CONSULTANT: [
    { href: '/consultant', label: 'Panel' },
    { href: '/consultant/inbox', label: 'Gelen Kutusu' },
    { href: '/consultant/listings', label: 'İlanlar' },
  ],
  HUNTER: [
    { href: '/hunter', label: 'Panel' },
    { href: '/hunter/leads', label: 'Leadlerim' },
    { href: '/hunter/leads/new', label: 'Yeni Lead' },
  ],
};

export function getRoleNav(role: ShellRole, extra: NavItem[] = []): NavItem[] {
  const map = new Map<string, NavItem>();
  [...baseRoleNav[role], ...extra].forEach((item) => {
    if (!map.has(item.href)) map.set(item.href, item);
  });
  return Array.from(map.values());
}
