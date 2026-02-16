export const colorTokens = {
  primary600: "#0b5fff",
  primary700: "#0847c7",
  success600: "#0e9f6e",
  warning600: "#d97706",
  danger600: "#dc2626",
  bg: "#f7f8fa",
  surface: "#ffffff",
  border: "#e5e7eb",
  textPrimary: "#111827",
  textSecondary: "#4b5563",
  textMuted: "#6b7280",
} as const;

export const typeScale = {
  display: { size: 40, line: 48 },
  h1: { size: 32, line: 40 },
  h2: { size: 24, line: 32 },
  h3: { size: 20, line: 28 },
  body: { size: 16, line: 24 },
  small: { size: 14, line: 20 },
  xs: { size: 12, line: 16 },
} as const;

export const spacingScale = {
  1: 4,
  2: 8,
  3: 12,
  4: 16,
  5: 20,
  6: 24,
  8: 32,
  10: 40,
  12: 48,
} as const;

export const radiusTokens = {
  sm: 6,
  md: 10,
  lg: 14,
} as const;

export const shadowTokens = {
  sm: "0 1px 2px rgba(0, 0, 0, 0.08)",
  md: "0 4px 12px rgba(0, 0, 0, 0.1)",
  lg: "0 10px 24px rgba(0, 0, 0, 0.14)",
} as const;
