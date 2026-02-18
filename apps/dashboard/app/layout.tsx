import "./globals.css";
import type { Metadata } from 'next';
import { montserrat } from "./fonts";
import ThemeProvider from '@/src/ui/theme/ThemeProvider';

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
      <body className={montserrat.variable}>
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
