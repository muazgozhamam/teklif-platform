'use client';

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";

type BannerTone = 'pending' | 'approved' | 'deal' | 'won' | 'rejected';


type TabKey = "all" | "pending" | "approved" | "deal" | "won";

const TABS: { key: TabKey; label: string; hint: string }[] = [
  { key: "all", label: "Tümü", hint: "Tüm lead’ler" },
  { key: "pending", label: "Onay Bekleyen", hint: "Broker incelemesinde" },
  { key: "approved", label: "Onaylanan", hint: "Broker approved" },
  { key: "deal", label: "Deal’e Dönen", hint: "Deal oluşturulmuş" },
  { key: "won", label: "Kazanılan", hint: "WON" },
];

type LeadJourney = {
  id: string;
  type: string;
  city?: string;
  district?: string;
  createdAtLabel: string;

  brokerStatus: "PENDING" | "APPROVED" | "REJECTED";
  dealId?: string;
  consultantEmail?: string;
  listingId?: string;
  listingStatus?: "DRAFT" | "PUBLISHED" | "ARCHIVED";
  dealStatus?: "OPEN" | "READY_FOR_MATCHING" | "ASSIGNED" | "WON" | "LOST";
};

type HunterStats = {
  role: "HUNTER";
  leadsTotal: number;
  leadsNew: number;
  leadsReview: number;
  leadsApproved: number;
  leadsRejected: number;
};

function StatCard(props: { title: string; value: string; sub?: string }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4 shadow-sm">
      <div className="text-sm text-white/60">{props.title}</div>
      <div className="mt-1 text-2xl font-semibold">{props.value}</div>
      {props.sub ? <div className="mt-1 text-xs text-white/50">{props.sub}</div> : null}
    </div>
  );
}

function Banner({ label, tone }: { label: string; tone: "pending" | "approved" | "deal" | "won" | "rejected" }) {
  const cls =
    tone === "won"
      ? "border-emerald-300/20 bg-emerald-400/10 text-emerald-200"
      : tone === "deal"
      ? "border-fuchsia-300/20 bg-fuchsia-400/10 text-fuchsia-200"
      : tone === "approved"
      ? "border-sky-300/20 bg-sky-400/10 text-sky-200"
      : tone === "rejected"
      ? "border-rose-300/20 bg-rose-400/10 text-rose-200"
      : "border-amber-300/20 bg-amber-400/10 text-amber-200";

  return (
    <span className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium ${cls}`}>
      {label}
    </span>
  );
}

function TimelineStep({ done, label }: { done: boolean; label: string }) {
  return (
    <div className="flex min-w-0 flex-col items-start gap-1">
      <div className="flex items-center gap-2">
        <span
          className={[
            "inline-block h-2.5 w-2.5 rounded-full border",
            done ? "border-white/40 bg-white/80" : "border-white/15 bg-white/5",
          ].join(" ")}
        />
        <span className={done ? "text-xs text-white/80" : "text-xs text-white/45"}>{label}</span>
      </div>
    </div>
  );
}

function Timeline({
  steps,
}: {
  steps: Array<{ label: string; done: boolean }>;
}) {
  // responsive: mobile = 2 columns, desktop = 4 columns
  // çizgi hissi: her step grubunun üstünde border + dotlar ile “●──●” algısı
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-3">
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {steps.map((s, idx) => (
          <div key={idx} className="relative">
            {/* connecting line (desktop only) */}
            <div className="hidden sm:block">
              <div className="absolute left-[6px] right-0 top-[6px] h-px bg-white/10" />
              <div className="absolute left-[6px] top-[6px] h-px bg-white/10" />
            </div>
            <TimelineStep done={s.done} label={s.label} />
          </div>
        ))}
      </div>
    </div>
  );
}

function MiniField({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-2">
      <div className="text-xs text-white/50">{label}</div>
      <div className="mt-0.5 truncate text-xs font-medium text-white/80">{value}</div>
    </div>
  );
}

function JourneyCard({ item }: { item: LeadJourney }) {
  const brokerApproved = item.brokerStatus === "APPROVED";
  const hasDeal = Boolean(item.dealId);
  const hasConsultant = Boolean(item.consultantEmail);
  const hasListing = Boolean(item.listingId);
  const listingPublished = item.listingStatus === "PUBLISHED";
  const won = item.dealStatus === "WON";

  const statusTone =
    won ? "won" :
    item.brokerStatus === "REJECTED" ? "rejected" :
    hasDeal ? "deal" :
    brokerApproved ? "approved" :
    "pending";

  const statusLabel =
    won ? "🏆 KAZANILDI (WON)" :
    item.brokerStatus === "REJECTED" ? "REDDEDİLDİ" :
    hasDeal ? "DEAL OLUŞTU" :
    brokerApproved ? "ONAYLANDI" :
    "ONAY BEKLİYOR";

  const cardGlow =
    statusTone === "won"
      ? "border-emerald-300/20 shadow-[0_0_0_1px_rgba(16,185,129,0.15),0_10px_30px_rgba(16,185,129,0.12)]"
      : statusTone === "deal"
      ? "border-fuchsia-300/15"
      : statusTone === "approved"
      ? "border-sky-300/15"
      : statusTone === "rejected"
      ? "border-rose-300/15"
      : "border-amber-300/15";

  const topStripe =
    statusTone === "won"
      ? "from-emerald-500/20 via-emerald-400/10 to-transparent"
      : statusTone === "deal"
      ? "from-fuchsia-500/20 via-fuchsia-400/10 to-transparent"
      : statusTone === "approved"
      ? "from-sky-500/20 via-sky-400/10 to-transparent"
      : statusTone === "rejected"
      ? "from-rose-500/20 via-rose-400/10 to-transparent"
      : "from-amber-500/20 via-amber-400/10 to-transparent";

  const steps = [
    { label: "Lead", done: true },
    { label: "Broker", done: item.brokerStatus !== "PENDING" },
    { label: "Approved", done: brokerApproved },
    { label: "Deal", done: hasDeal },
    { label: "Consultant", done: hasConsultant },
    { label: "Listing", done: hasListing },
    { label: "Publish", done: listingPublished },
    { label: "WON", done: won },
  ];

  return (
    <div className={`relative overflow-hidden rounded-2xl border bg-white/5 p-4 shadow-sm ${cardGlow}`}>
      {/* top stripe */}
      <div className={`pointer-events-none absolute inset-x-0 top-0 h-20 bg-gradient-to-b ${topStripe}`} />

      <div className="relative flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <div className="text-xs text-white/60">Lead</div>
            <Banner label={statusLabel} tone={statusTone as BannerTone} />
          </div>

          <div className="mt-2 truncate text-lg font-semibold">{item.type}</div>
          <div className="mt-1 text-xs text-white/55">
            {item.id} • {item.createdAtLabel} • {(item.city ?? "—")} / {(item.district ?? "—")}
          </div>
        </div>

        <Link
          href={`/hunter/leads/${encodeURIComponent(item.id)}`}
          className="rounded-2xl border border-white/10 bg-white/10 px-3 py-1.5 text-sm font-medium hover:bg-white/15"
        >
          Aç
        </Link>
      </div>

      <div className="relative mt-4">
        <Timeline steps={steps} />
      </div>

      <div className="relative mt-3 grid grid-cols-2 gap-2">
        <MiniField label="Broker" value={item.brokerStatus} />
        <MiniField label="Deal" value={item.dealStatus ?? (item.dealId ? "—" : "Yok")} />
        <MiniField label="Consultant" value={item.consultantEmail ?? "—"} />
        <MiniField label="Listing" value={item.listingStatus ?? (item.listingId ? "—" : "Yok")} />
      </div>
    </div>
  );
}

export default function HunterDashboardPage() {
  const [tab, setTab] = useState<TabKey>("all");
  const [q, setQ] = useState("");
  const [stats, setStats] = useState<HunterStats | null>(null);
  const [statsLoading, setStatsLoading] = useState(true);
  const [statsError, setStatsError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    async function loadStats() {
      setStatsLoading(true);
      setStatsError(null);
      try {
        const res = await api.get<HunterStats | { role: string }>('/stats/me');
        const data = res.data;
        if (!mounted) return;
        if (data && (data as { role?: string }).role === 'HUNTER') {
          setStats(data as HunterStats);
        } else {
          setStats(null);
        }
      } catch {
        if (!mounted) return;
        setStats(null);
        setStatsError('Metrikler yüklenemedi.');
      } finally {
        if (mounted) setStatsLoading(false);
      }
    }
    loadStats();
    return () => {
      mounted = false;
    };
  }, []);

  // Şimdilik mock: bir sonraki adımda GET /hunter/leads ile dolduracağız
  const rows = useMemo<LeadJourney[]>(() => ([
    {
      id: "ld_0001",
      type: "Konut Alım",
      city: "Konya",
      district: "Meram",
      createdAtLabel: "Bugün",
      brokerStatus: "PENDING",
    },
    {
      id: "ld_0002",
      type: "Kiralık Daire",
      city: "Konya",
      district: "Selçuklu",
      createdAtLabel: "Dün",
      brokerStatus: "APPROVED",
      dealId: "deal_12",
      dealStatus: "ASSIGNED",
      consultantEmail: "consultant1@test.com",
      listingId: "lst_77",
      listingStatus: "DRAFT",
    },
    {
      id: "ld_0003",
      type: "Arsa",
      city: "Konya",
      district: "Karatay",
      createdAtLabel: "3 gün önce",
      brokerStatus: "APPROVED",
      dealId: "deal_33",
      dealStatus: "WON",
      consultantEmail: "consultant1@test.com",
      listingId: "lst_91",
      listingStatus: "PUBLISHED",
    },
  ]), []);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();

    return rows.filter((r) => {
      // tab filter
      if (tab === "pending" && r.brokerStatus !== "PENDING") return false;
      if (tab === "approved" && r.brokerStatus !== "APPROVED") return false;
      if (tab === "deal" && !r.dealId) return false;
      if (tab === "won" && r.dealStatus !== "WON") return false;

      // search filter
      if (!needle) return true;
      const hay = [
        r.id,
        r.type,
        r.city ?? "",
        r.district ?? "",
        r.consultantEmail ?? "",
        r.dealId ?? "",
        r.listingId ?? "",
      ].join(" ").toLowerCase();
      return hay.includes(needle);
    });
  }, [tab, q, rows]);

  // KPI
  const kpi = useMemo(() => {
    const total = rows.length;
    const pending = rows.filter((r) => r.brokerStatus === "PENDING").length;
    const approved = rows.filter((r) => r.brokerStatus === "APPROVED").length;
    const deal = rows.filter((r) => Boolean(r.dealId)).length;
    const won = rows.filter((r) => r.dealStatus === "WON").length;
    return { total, pending, approved, deal, won };
  }, [rows]);

  return (
    <div className="mx-auto w-full max-w-6xl p-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <div className="text-sm text-white/60">Hunter Panel</div>
          <h1 className="mt-1 text-2xl font-semibold">Dashboard</h1>
          <div className="mt-2 text-sm text-white/60">
            Lead’lerini takip et. Her lead’in yolculuğunu (Broker → Deal → Listing → WON) tek ekranda gör.
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Link
            href="/hunter/leads/new"
            className="rounded-2xl border border-white/10 bg-white/10 px-4 py-2 text-sm font-medium hover:bg-white/15"
          >
            + Yeni Lead
          </Link>
          <Link
            href="/hunter/leads"
            className="rounded-2xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium hover:bg-white/10"
          >
            Lead Listesi
          </Link>
        </div>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
        {statsLoading ? (
          <>
            <div className="h-20 animate-pulse rounded-2xl border border-white/10 bg-white/5" />
            <div className="h-20 animate-pulse rounded-2xl border border-white/10 bg-white/5" />
            <div className="h-20 animate-pulse rounded-2xl border border-white/10 bg-white/5" />
            <div className="h-20 animate-pulse rounded-2xl border border-white/10 bg-white/5" />
            <div className="h-20 animate-pulse rounded-2xl border border-white/10 bg-white/5" />
          </>
        ) : (
          <>
            <StatCard title="Toplam Lead" value={String(stats?.leadsTotal ?? kpi.total)} sub="Tüm zamanlar" />
            <StatCard title="Yeni" value={String(stats?.leadsNew ?? kpi.pending)} sub="NEW" />
            <StatCard title="İncelemede" value={String(stats?.leadsReview ?? 0)} sub="REVIEW" />
            <StatCard title="Onaylanan" value={String(stats?.leadsApproved ?? kpi.approved)} sub="APPROVED" />
            <StatCard title="Reddedilen" value={String(stats?.leadsRejected ?? 0)} sub="REJECTED" />
          </>
        )}
      </div>
      {statsError ? <div className="mt-2 text-sm text-rose-300">{statsError}</div> : null}

      <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-wrap gap-2">
          {TABS.map((t) => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={[
                "rounded-2xl border px-3 py-1.5 text-sm",
                t.key === tab
                  ? "border-white/20 bg-white/15"
                  : "border-white/10 bg-white/5 hover:bg-white/10",
              ].join(" ")}
              title={t.hint}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-2">
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Ara: şehir, ilçe, tip, id…"
            className="w-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm outline-none placeholder:text-white/40 focus:border-white/20 sm:w-80"
          />
          <button className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm hover:bg-white/10">
            Filtre
          </button>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        {filtered.length === 0 ? (
          <div className="rounded-2xl border border-white/10 bg-white/5 p-6 text-sm text-white/60">
            Sonuç yok. Yeni lead eklemek için <span className="text-white/80">+ Yeni Lead</span>.
          </div>
        ) : (
          filtered.map((item) => <JourneyCard key={item.id} item={item} />)
        )}
      </div>

      <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-white/70">
        <div className="font-medium text-white/85">Sonraki adım</div>
        <ul className="mt-2 list-disc pl-5">
          <li>
            Bu ekranı gerçek veriye bağlayacağız: <span className="text-white/80">GET /hunter/leads</span>
          </li>
          <li>
            Lead → broker → deal → listing ilişkisini API’den tek response ile almak için “journey view” endpoint’i çıkaracağız.
          </li>
          <li>Tahmini komisyon ve hedef metriklerini buraya ekleyeceğiz.</li>
        </ul>
      </div>
    </div>
  );
}
