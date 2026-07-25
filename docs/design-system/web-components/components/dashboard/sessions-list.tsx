import { Link } from "@tanstack/react-router";
import { ArrowRight } from "lucide-react";

import type { SessionSummary } from "@/lib/api/sessions";

const PRESENTATION_LABEL: Record<string, string> = {
  tesis: "Tesis",
  pitch: "Pitch",
  entrevista: "Entrevista",
  reporte_ejecutivo: "Reporte ejecutivo",
  clase: "Clase",
};

const STATUS_LABEL: Record<string, { label: string; tone: string }> = {
  created: { label: "Sin grabar", tone: "bg-surface-2 text-ink-soft ring-line" },
  in_progress: {
    label: "Audio cargado",
    tone: "bg-sky-500/10 text-sky-300 ring-sky-500/20",
  },
  processing: {
    label: "Procesando",
    tone: "bg-amber-500/10 text-amber-300 ring-amber-500/20",
  },
  completed: {
    label: "Completada",
    tone: "bg-accent/10 text-accent ring-accent/25",
  },
  failed: { label: "Fallida", tone: "bg-red-500/10 text-red-300 ring-red-500/20" },
  canceled: { label: "Cancelada", tone: "bg-surface-2 text-ink-faint ring-line" },
};

interface SessionsListProps {
  sessions: SessionSummary[];
}

export function SessionsList({ sessions }: SessionsListProps) {
  if (sessions.length === 0) return null;
  return (
    <ul className="flex flex-col gap-2">
      {sessions.map((s) => (
        <li key={s.id}>
          <Link
            to="/reports/$reportId"
            params={{ reportId: s.id }}
            className="grid grid-cols-[1fr_auto_auto] items-center gap-4 rounded-xl bg-surface p-4 transition-colors hover:bg-surface-2"
          >
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <h4 className="truncate text-sm font-semibold text-ink">
                  {presentationTitle(s)}
                </h4>
                <StatusBadge status={s.status} />
              </div>
              <p className="mt-1 text-xs text-ink-faint">
                {formatDate(s.created_at)} · {formatDuration(s.duration_seconds)}
              </p>
            </div>
            <div className="flex flex-col items-end">
              <span className="font-display text-xl font-semibold leading-none tracking-tight tabular-nums text-accent">
                {s.score ?? "—"}
              </span>
              <span className="mt-0.5 text-[10px] font-semibold uppercase tracking-wider text-ink-faint">
                Score
              </span>
            </div>
            <ArrowRight className="h-4 w-4 text-ink-faint" strokeWidth={2} />
          </Link>
        </li>
      ))}
    </ul>
  );
}

function StatusBadge({ status }: { status: string }) {
  const meta = STATUS_LABEL[status] ?? {
    label: status,
    tone: "bg-surface-2 text-ink-soft ring-line",
  };
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider ring-1 ${meta.tone}`}
    >
      {meta.label}
    </span>
  );
}

function presentationTitle(s: SessionSummary): string {
  const ctx = s.context as { presentation_type?: unknown };
  const raw =
    typeof ctx?.presentation_type === "string" ? ctx.presentation_type : "";
  if (raw) return PRESENTATION_LABEL[raw] ?? raw;
  return s.type === "async" ? "Sesión asíncrona" : "Sesión en vivo";
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
  return created.toLocaleDateString("es", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

function formatDuration(seconds: number | null): string {
  if (!seconds) return "—";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  if (m === 0) return `${s} s`;
  return `${m} min`;
}
