'use client';

import { ApplicationsListPage } from '../_components/applications-shared';

export default function Page() {
  return <ApplicationsListPage title="Destek / Şikayet" subtitle="Support request ve complaint kayıtları." forcedType="SUPPORT_REQUEST,COMPLAINT" />;
}
