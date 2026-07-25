/**
 * Session timeline — the history as a progression, in the app's editorial
 * voice (mono metadata, display headlines, the score-ring motif that rhymes
 * with the report page). Sessions are grouped by relative date along a spine;
 * the most recent one gets a featured treatment so the grid isn't uniform, and
 * status is encoded by weight (a failed run shouts, a completed one is calm).
 */
import { Link } from "@tanstack/react-router";
import { ArrowRight, TrendingDown, TrendingUp } from "lucide-react";

import type { SessionSummary } from "@/lib/api/sessions";
import { cn } from "@/lib/utils";

const PRESENTATION_LABEL: Record<string, string> = {
  tesis: "Tesis",
  pitch: "Pitch",
  entrevista: "Entrevista",
  reporte_ejecutivo: "Reporte ejecutivo",
  clase: "Clase",
};

interface StatusMeta {
  label: string;
  dot: string;
  text: string;
}

const STATUS_META: Record<string, StatusMeta> = {
  created: { label: "Sin grabar", dot: "bg-ink-faint", text: "text-ink-faint" },
  in_progress: {
    label: "Audio cargado",
    dot: "bg-sky-500",
    text: "text-ink-soft",
  },
  processing: {
    label: "Procesando",
    dot: "bg-amber-500 animate-pulse",
    text: "text-amber-600 font-semibold",
  },
  completed: {
    label: "Completada",
    dot: "bg-emerald-500",
    text: "text-ink-soft",
  },
  // Worst state gets the most contrast (Von Restorff): a failed run should stand out.
  failed: {
    label: "Fallida",
    dot: "bg-rose-500",
    text: "text-rose-500 font-bold",
  },
  canceled: { label: "Cancelada", dot: "bg-ink-faint", text: "text-ink-faint" },
};

/** Band → text color class; the ring stroke + number inherit it via currentColor. */
function bandColor(score: number | null): string {
  if (score === null) return "text-ink-faint";
  if (score >= 85) return "text-emerald-600";
  if (score >= 70) return "text-lime-600";
  if (score >= 50) return "text-amber-600";
  return "text-rose-500";
}

function presentationTitle(s: SessionSummary): string {
  const ctx = s.context as { presentation_type?: unknown };
  const raw =
    typeof ctx?.presentation_type === "string" ? ctx.presentation_type : "";
  if (raw) return PRESENTATION_LABEL[raw] ?? raw;
  return s.type === "async" ? "Sesión asíncrona" : "Sesión en vivo";
}

function startOfDay(d: Date): number {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x.getTime();
}

function bucketOf(iso: string): string {
  const d = new Date(iso);
  const days = Math.round(
    (startOfDay(new Date()) - startOfDay(d)) / 86_400_000,
  );
  if (days <= 0) return "Hoy";
  if (days === 1) return "Ayer";
  if (days < 7) return "Esta semana";
  if (days < 30) return "Este mes";
  return d.toLocaleDateString("es", { month: "long", year: "numeric" });
}

function relativeTime(iso: string): string {
  const created = new Date(iso);
  const diffMs = Date.now() - created.getTime();
  const diffH = Math.floor(diffMs / 3_600_000);
  if (diffH < 1) return `Hace ${Math.max(1, Math.round(diffMs / 60_000))} min`;
  if (diffH < 24) return `Hace ${diffH} h`;
  return created.toLocaleDateString("es", { day: "numeric", month: "short" });
}

function durationLabel(seconds: number | null): string | null {
  if (!seconds) return null;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return m === 0 ? `${s} s` : `${m} min`;
}

// ── Score ring (motif shared with the report's ScoreRing) ────────────────────

function ScoreRing({
  score,
  size,
  featured,
}: {
  score: number | null;
  size: number;
  featured?: boolean;
}) {
  const stroke = featured ? 5 : 4;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const pct = score === null ? 0 : Math.max(0, Math.min(100, score)) / 100;

  return (
    <span
      className={cn("relative grid place-items-center", bandColor(score))}
      style={{ width: size, height: size }}
    >
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="var(--color-line)"
          strokeWidth={stroke}
        />
        {score !== null && (
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke="currentColor"
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={c}
            strokeDashoffset={c * (1 - pct)}
          />
        )}
      </svg>
      <span className="absolute flex flex-col items-center leading-none">
        <span
          className={cn(
            "font-display font-bold tabular-nums",
            featured ? "text-2xl" : "text-base",
          )}
        >
          {score ?? "—"}
        </span>
      </span>
    </span>
  );
}

// ── Timeline ─────────────────────────────────────────────────────────────────

export function SessionTimeline({ sessions }: { sessions: SessionSummary[] }) {
  // Delta vs the previous COMPLETED session (chronological), keyed by id.
  const chrono = sessions
    .filter((s) => s.status === "completed" && s.score !== null)
    .slice()
    .sort(
      (a, b) =>
        new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
    );
  const deltaById = new Map<string, number>();
  for (let i = 1; i < chrono.length; i++) {
    deltaById.set(
      chrono[i].id,
      (chrono[i].score as number) - (chrono[i - 1].score as number),
    );
  }

  // Group (input is newest-first) into date buckets, first-seen order preserved.
  const groups: { label: string; items: SessionSummary[] }[] = [];
  for (const s of sessions) {
    const label = bucketOf(s.created_at);
    const last = groups[groups.length - 1];
    if (last && last.label === label) last.items.push(s);
    else groups.push({ label, items: [s] });
  }

  return (
    <div className="flex flex-col gap-10">
      {groups.map((group, gi) => (
        <section key={group.label}>
          <div className="mb-5 flex items-baseline gap-3">
            <h3 className="font-mono text-[11px] font-medium uppercase tracking-[0.22em] text-ink-faint">
              {group.label}
            </h3>
            <span className="h-px flex-1 bg-line" />
            <span className="font-display text-2xl font-bold tabular-nums text-ink-faint/25">
              {group.items.length}
            </span>
          </div>

          {/* Spine + nodes. Warm at the top (most recent), fading down. */}
          <div className="relative">
            <span
              aria-hidden
              className="absolute bottom-6 left-9 top-6 w-px bg-gradient-to-b from-accent/40 via-line to-transparent"
            />
            <ol className="flex flex-col gap-2">
              {group.items.map((s, i) => (
                <TimelineNode
                  key={s.id}
                  session={s}
                  delta={deltaById.get(s.id)}
                  featured={gi === 0 && i === 0}
                />
              ))}
            </ol>
          </div>
        </section>
      ))}
    </div>
  );
}

function TimelineNode({
  session: s,
  delta,
  featured,
}: {
  session: SessionSummary;
  delta: number | undefined;
  featured?: boolean;
}) {
  const status = STATUS_META[s.status] ?? {
    label: s.status,
    dot: "bg-ink-faint",
    text: "text-ink-soft",
  };
  const duration = durationLabel(s.duration_seconds);

  return (
    <li className="relative grid grid-cols-[72px_1fr] items-start gap-3 sm:gap-4">
      {/* Node on the spine (stage disc cuts the line cleanly). */}
      <div className="flex justify-center pt-1">
        <span className="z-10 rounded-full bg-stage p-1.5">
          <ScoreRing
            score={s.score}
            size={featured ? 64 : 52}
            featured={featured}
          />
        </span>
      </div>

      <Link
        to="/reports/$reportId"
        params={{ reportId: s.id }}
        className={cn(
          "group flex flex-col gap-2 rounded-2xl px-4 py-3.5 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent",
          featured
            ? "relative overflow-hidden border border-line bg-surface p-5 shadow-[0_12px_40px_-20px_rgba(0,0,0,0.35)]"
            : "hover:bg-surface",
        )}
      >
        {featured && <EqMotif />}

        <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1">
          <h4
            className={cn(
              "font-semibold text-ink",
              featured ? "font-display text-xl" : "text-sm",
            )}
          >
            {presentationTitle(s)}
          </h4>
          <StatusTag status={status} />
          {delta !== undefined && <DeltaTag delta={delta} />}
          <ArrowRight
            className="ml-auto h-4 w-4 shrink-0 -translate-x-1 text-ink-faint opacity-0 transition-all group-hover:translate-x-0 group-hover:opacity-100"
            strokeWidth={2}
            aria-hidden
          />
        </div>

        <p className="font-mono text-[11px] uppercase tracking-[0.12em] text-ink-faint">
          {relativeTime(s.created_at)}
          {duration && <> · {duration}</>}
          {s.score !== null && (
            <>
              {" · "}
              {s.score}
              <span className="text-ink-faint/60">/100</span>
            </>
          )}
        </p>

        {s.summary && (
          <p
            className={cn(
              "leading-relaxed text-ink-soft",
              featured ? "text-sm line-clamp-3" : "text-[13px] line-clamp-2",
            )}
          >
            {s.summary}
          </p>
        )}
      </Link>
    </li>
  );
}

function StatusTag({ status }: { status: StatusMeta }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-[0.16em]",
        status.text,
      )}
    >
      <span
        className={cn("h-1.5 w-1.5 rounded-full", status.dot)}
        aria-hidden
      />
      {status.label}
    </span>
  );
}

function DeltaTag({ delta }: { delta: number }) {
  const up = delta > 0;
  const flat = delta === 0;
  return (
    <span
      className={cn(
        "inline-flex items-center gap-0.5 font-mono text-[10px] font-semibold tabular-nums",
        flat ? "text-ink-faint" : up ? "text-emerald-600" : "text-rose-500",
      )}
    >
      {!flat &&
        (up ? (
          <TrendingUp className="h-3 w-3" strokeWidth={2.4} aria-hidden />
        ) : (
          <TrendingDown className="h-3 w-3" strokeWidth={2.4} aria-hidden />
        ))}
      {up ? "+" : ""}
      {delta}
    </span>
  );
}

/** Brand motif: a slow equalizer, signalling the audio/oratory core. */
function EqMotif() {
  return (
    <span
      aria-hidden
      className="absolute right-5 top-5 flex h-5 items-end gap-0.5 opacity-70"
    >
      {[0, 1, 2, 3].map((i) => (
        <span
          key={i}
          className="eq-bar w-0.5 rounded-full bg-accent"
          style={{ height: "100%", animationDelay: `${i * 0.15}s` }}
        />
      ))}
    </span>
  );
}
