import { Link } from "@tanstack/react-router";
import { ArrowRight } from "lucide-react";

import { CountUp } from "@/components/anim/count-up";
import type { SessionSummary } from "@/lib/api/sessions";

interface LastSessionCardProps {
  session: SessionSummary;
}

function formatDate(iso: string): string {
  const created = new Date(iso);
  const now = new Date();
  const diffMs = now.getTime() - created.getTime();
  const diffH = Math.floor(diffMs / (60 * 60 * 1000));
  if (diffH < 1) {
    const diffMin = Math.max(1, Math.round(diffMs / (60 * 1000)));
    return `Hace ${diffMin} min`;
  }
  if (diffH < 24) return `Hace ${diffH} h`;
  const diffD = Math.floor(diffH / 24);
  if (diffD === 1) return "Ayer";
  if (diffD < 7) return `Hace ${diffD} días`;
  return created.toLocaleDateString("es", { day: "numeric", month: "short" });
}

function formatDuration(seconds: number | null): string {
  if (!seconds) return "—";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  if (m === 0) return `${s} s`;
  return `${m} min`;
}

export function LastSessionCard({ session }: LastSessionCardProps) {
  const summary = session.summary?.trim()
    ? session.summary
    : "Sesión completada — abrí el reporte para los detalles.";
  return (
    <div className="rounded-2xl bg-surface p-6">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h4 className="text-base font-semibold tracking-tight text-ink">
            Sesión de práctica
          </h4>
          <p className="mt-1 text-xs text-ink-faint">
            {formatDate(session.created_at)} ·{" "}
            {formatDuration(session.duration_seconds)}
          </p>
        </div>
        <div className="shrink-0 text-right">
          <span className="font-display block text-3xl font-bold leading-none tabular-nums text-accent">
            {session.score === null ? "—" : <CountUp value={session.score} />}
          </span>
          <span className="text-[10px] font-medium uppercase tracking-wider text-ink-faint">
            Score
          </span>
        </div>
      </div>

      <p className="mt-3 line-clamp-3 text-[13px] leading-relaxed text-ink-soft">
        {summary}
      </p>

      <Link
        to="/reports/$reportId"
        params={{ reportId: session.id }}
        className="mt-4 inline-flex h-10 w-full items-center justify-center gap-2 rounded-lg bg-surface-2 text-sm font-semibold text-ink transition-colors hover:bg-line"
      >
        Ver reporte
        <ArrowRight className="h-4 w-4 text-accent" strokeWidth={2} />
      </Link>
    </div>
  );
}
