import "./globals.css";
import type { Metadata } from 'next';
import { montserrat } from "./fonts";

export const metadata: Metadata = {
  title: {
    default: 'SatDedi | Dashboard',
    template: 'SatDedi | %s',
  },
  description: 'SatDedi role-based emlak operasyon paneli',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr">
      <body className={montserrat.variable}>{children}</body>
    </html>
  );
}
