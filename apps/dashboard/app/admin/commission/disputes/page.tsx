'use client';

import RoleShell from '@/app/_components/RoleShell';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Alert } from '@/src/ui/components/Alert';

export default function AdminCommissionDisputesPage() {
  return (
    <RoleShell role="ADMIN" title="Hakediş Uyuşmazlıkları" subtitle="Dispute/SLA modülü Faz 2 kapsamında devreye alınacak." nav={[]}>
      <Alert
        type="warning"
        message="Bu sayfa Faz 1’de placeholder durumundadır. Uyuşmazlık kayıtları ve SLA akışı Faz 2’de aktif olacaktır."
        className="mb-4"
      />

      <Card>
        <CardTitle>Planlanan Özellikler</CardTitle>
        <CardDescription>
          Attribution claim, evidence metadata, SLA due, escalation ve karar geçmişi bu modülde yönetilecek.
        </CardDescription>
      </Card>
    </RoleShell>
  );
}
