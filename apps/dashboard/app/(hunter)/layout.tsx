import Link from "next/link";
import type { ReactNode } from "react";

export default function HunterLayout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen">
      {/* Hunter top bar */}
      <div className="border-b border-white/10 bg-white/5">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-3">
          <div className="flex items-center gap-3">
            <div className="text-sm font-semibold">satdedi.com</div>
            <span className="rounded-full border border-white/10 bg-white/10 px-2 py-0.5 text-xs text-white/80">
              Hunter
            </span>
          </div>

          <nav className="flex items-center gap-2 text-sm">
            <Link
              href="/hunter/dashboard"
              className="rounded-2xl border border-white/10 bg-white/5 px-3 py-1.5 hover:bg-white/10"
            >
              Panel
            </Link>
            <Link
              href="/hunter/leads"
              className="rounded-2xl border border-white/10 bg-white/5 px-3 py-1.5 hover:bg-white/10"
            >
              Lead’lerim
            </Link>
            <Link
              href="/hunter/leads/new"
              className="rounded-2xl border border-white/10 bg-white/10 px-3 py-1.5 font-medium hover:bg-white/15"
            >
              + Yeni Talep
            </Link>
          </nav>
        </div>
      </div>

      <main>{children}</main>
    </div>
  );
}
