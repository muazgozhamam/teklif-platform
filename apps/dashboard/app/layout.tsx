import "./globals.css";
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: {
    default: 'Satdedi | Dashboard',
    template: 'Satdedi | %s',
  },
  description: 'Satdedi role-based emlak operasyon paneli',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr">
      <body>{children}</body>
    </html>
  );
}
