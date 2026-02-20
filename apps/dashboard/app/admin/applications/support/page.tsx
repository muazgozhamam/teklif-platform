'use client';

import { ApplicationsListPage } from '../_components/applications-shared';

export default function Page() {
  return <ApplicationsListPage title="Destek / Şikayet" subtitle="Destek taleplerini ve şikayet kayıtlarını yönetin." forcedType="SUPPORT_REQUEST,COMPLAINT" />;
}
