import React from "react";
import Logo from "@/components/brand/Logo";

type LandingShellProps = {
  children: React.ReactNode;
  footer?: React.ReactNode;
};

export default function LandingShell({ children, footer }: LandingShellProps) {
  return (
    <main className="min-h-screen" style={{ background: "var(--color-bg)", color: "var(--color-text-primary)" }}>
      <div className="mx-auto flex min-h-screen w-full max-w-[960px] flex-col px-4 py-6 md:px-6">
        {children}
        {footer ? (
          <div className="pb-2 pt-4 text-center text-xs" style={{ color: "var(--color-text-muted)" }}>
            <div className="mb-1">
              <Logo size="sm" className="text-lg" />
            </div>
            {footer}
          </div>
        ) : null}
      </div>
    </main>
  );
}

