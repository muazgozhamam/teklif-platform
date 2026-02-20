'use client';

import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { CardDescription, CardTitle } from '@/src/ui/components/Card';

export default function Page() {
  return (
    <RoleShell role="ADMIN" title="Performans - Genel" subtitle="Rol bazlı sıralama panellerine geçiş." nav={[]}>
      <div className="grid gap-3 md:grid-cols-3">
        <Link href="/admin/leaderboards/hunter" className="ui-interactive rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <CardTitle>İş Ortağı Sıralama</CardTitle>
          <CardDescription>Kalite ağırlıklı iş ortağı skoru.</CardDescription>
        </Link>
        <Link href="/admin/leaderboards/consultant" className="ui-interactive rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <CardTitle>Danışman Sıralama</CardTitle>
          <CardDescription>Dönüşüm + GMV odaklı skor.</CardDescription>
        </Link>
        <Link href="/admin/leaderboards/broker" className="ui-interactive rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
          <CardTitle>Broker Sıralama</CardTitle>
          <CardDescription>İşlem + onay kalitesi skoru.</CardDescription>
        </Link>
      </div>
    </RoleShell>
  );
}
