export default async function HunterLeadDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return (
    <div className="mx-auto w-full max-w-6xl p-6">
      <div className="text-sm text-white/60">Hunter</div>
      <h1 className="mt-1 text-2xl font-semibold">Lead Detay</h1>
      <div className="mt-2 text-sm text-white/60">ID: {id}</div>

      <div className="mt-4 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-white/70">
        Bu sayfa lead → broker → deal → listing → WON izini gösterecek.
      </div>
    </div>
  );
}
