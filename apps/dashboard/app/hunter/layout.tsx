export default function HunterLayout({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ padding: 24, maxWidth: 960, margin: "0 auto" }}>
      {children}
    </div>
  );
}
