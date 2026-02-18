'use client';

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Alert } from '@/src/ui/components/Alert';

export default function AdminCommissionPoliciesPage() {
  return (
    <RoleShell
      role="ADMIN"
      title="Komisyon Politikaları"
      subtitle="Yönetim tarafı komisyon kural ve oran ekranı."
      nav={[]}
    >
      <Alert
        type="info"
        message="Bu ekran komisyon policy/version yönetimi için ayrıldı. Operasyonel hakediş işlemleri Hakediş menüsünde devam eder."
        className="mb-4"
      />

      <div className="grid gap-3 md:grid-cols-2">
        <Card>
          <CardTitle>Politika Versiyonları</CardTitle>
          <CardDescription className="mt-1">
            Effective date, split oranları ve hesaplama metodu yönetimi burada gösterilecek.
          </CardDescription>
        </Card>

        <Card>
          <CardTitle>Operasyon Ekranı</CardTitle>
          <CardDescription className="mt-1">
            Snapshot, onay, payout ve dispute işlemlerine devam etmek için Hakediş Genel Bakış ekranını kullan.
          </CardDescription>
          <div className="mt-3">
            <Link
              href="/admin/commission"
              className="ui-interactive inline-flex h-9 items-center rounded-lg border border-[var(--border)] px-3 text-sm hover:bg-[var(--interactive-hover-bg)]"
            >
              Hakediş Genel Bakışa Git
            </Link>
          </div>
        </Card>
      </div>
    </RoleShell>
  );
}
