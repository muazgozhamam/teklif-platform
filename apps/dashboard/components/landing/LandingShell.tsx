import React from "react";
import Logo from "@/components/brand/Logo";

type LandingShellProps = {
  children: React.ReactNode;
  footer?: React.ReactNode;
};

export default function LandingShell({ children, footer }: LandingShellProps) {
  return (
    <main className="min-h-screen w-full" style={{ background: "var(--color-bg)", color: "var(--color-text-primary)" }}>
      <div className="flex min-h-screen w-full flex-col px-6 py-6 md:px-8">
        <div className="mx-auto flex w-full max-w-[1280px] flex-1 flex-col">
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
      </div>
    </main>
  );
}
