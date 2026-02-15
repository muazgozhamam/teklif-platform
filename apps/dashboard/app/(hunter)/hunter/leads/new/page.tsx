export default function HunterNewLeadPage() {
  return (
    <div className="mx-auto w-full max-w-6xl p-6">
      <div className="text-sm text-white/60">Hunter</div>
      <h1 className="mt-1 text-2xl font-semibold">Yeni Lead</h1>
      <div className="mt-4 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-white/70">
        Bu sayfa bir sonraki adımda lead formu + wizard ile yapılacak (POST /hunter/leads).
      </div>
    </div>
  );
}
