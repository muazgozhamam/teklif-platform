import Link from "next/link";
import React from "react";

type Variant = "primary" | "outline" | "ghost";

type LandingActionButtonProps = {
  href: string;
  label: string;
  ariaLabel?: string;
  variant?: Variant;
};

export default function LandingActionButton({
  href,
  label,
  ariaLabel,
  variant = "outline",
}: LandingActionButtonProps) {
  const shared = "inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium transition-colors";

  const styleByVariant: Record<Variant, React.CSSProperties> = {
    primary: {
      background: "var(--color-primary-600)",
      color: "#ffffff",
      border: "1px solid var(--color-primary-600)",
    },
    outline: {
      background: "transparent",
      color: "var(--color-text-secondary)",
      border: "1px solid var(--color-border)",
    },
    ghost: {
      background: "transparent",
      color: "var(--color-text-secondary)",
      border: "1px solid transparent",
    },
  };

  return (
    <Link
      href={href}
      aria-label={ariaLabel || label}
      className={shared}
      style={styleByVariant[variant]}
    >
      {label}
    </Link>
  );
}
