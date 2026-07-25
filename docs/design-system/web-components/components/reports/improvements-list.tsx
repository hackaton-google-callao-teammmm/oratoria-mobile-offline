import { humanizeEvidence } from "@/lib/reports/format";

import { DIMENSION_META, type Dimension } from "./strengths-list";

export type Priority = "high" | "medium" | "low";

export interface Improvement {
  title: string;
  description?: string;
  dimension?: Dimension | string;
  evidence?: string;
  suggestion?: string;
  priority?: Priority | string;
}

const PRIORITY_TEXT: Record<string, string> = {
  high: "Prioridad alta",
  medium: "Prioridad media",
  low: "Prioridad baja",
};

const PRIORITY_ORDER: Record<string, number> = { high: 0, medium: 1, low: 2 };

export function priorityOrder(p: string | undefined): number {
  return p !== undefined ? (PRIORITY_ORDER[p] ?? 3) : 3;
}

interface ImprovementsListProps {
  items: Improvement[];
}

/**
 * Same editorial card as StrengthCard. The actionable takeaway ("Cómo
 * mejorarlo") gets a stronger lime treatment — it is the one thing the user
 * should do next. Priority is signalled by ORDER + a monospace eyebrow.
 */
export function ImprovementCard({
  m,
  index = 0,
}: {
  m: Improvement;
  index?: number;
}) {
  const meta = m.dimension ? DIMENSION_META[m.dimension] : undefined;
  const num = String(index + 1).padStart(2, "0");
  const prio = m.priority ? PRIORITY_TEXT[m.priority] : undefined;

  return (
    <article className="relative isolate overflow-hidden rounded-lg border border-line bg-surface p-6 sm:p-8">
      {/* Layered brand "target" motif in the corner — crisp concentric rings. */}
      <div
        aria-hidden
        className="pointer-events-none absolute right-0 top-0 -z-10"
      >
        <span className="absolute -right-16 -top-16 h-44 w-44 rounded-full bg-lime/[0.08]" />
        <span className="absolute -right-9 -top-9 h-28 w-28 rounded-full bg-lime/[0.16]" />
        <span className="absolute -right-2 -top-2 h-16 w-16 rounded-full bg-lime/[0.24]" />
      </div>

      <span
        aria-hidden
        className="font-display pointer-events-none absolute right-5 top-2 z-[1] select-none text-7xl font-black leading-none tracking-tighter text-accent/70"
      >
        {num}
      </span>

      <div className="h-[3px] w-9 rounded-full bg-lime" />

      <div className="mt-3 flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
        <p className="font-mono text-[10px] font-medium uppercase tracking-[0.24em] text-ink-faint">
          Área de mejora{meta ? ` · ${meta.label}` : ""}
        </p>
        {prio && (
          <p
            className={`font-mono text-[10px] font-semibold uppercase tracking-[0.24em] ${
              m.priority === "high" ? "text-ink" : "text-ink-faint"
            }`}
          >
            · {prio}
          </p>
        )}
      </div>

      <h3 className="font-display mt-2 max-w-[28ch] text-2xl font-bold leading-[1.12] tracking-tight text-ink sm:text-[26px]">
        {m.title}
      </h3>

      {m.description && (
        <p className="mt-3.5 max-w-prose text-[15px] leading-relaxed text-ink-soft">
          {m.description}
        </p>
      )}

      {m.evidence && (
        <div className="mt-6 border-l-2 border-line pl-4">
          <p className="font-mono text-[10px] font-medium uppercase tracking-[0.2em] text-ink-faint">
            Evidencia
          </p>
          <p className="mt-1.5 text-[15px] italic leading-relaxed text-ink-soft">
            {humanizeEvidence(m.evidence)}
          </p>
        </div>
      )}

      {m.suggestion && (
        <div className="mt-6 rounded-r-md border-l-[3px] border-lime bg-lime/[0.06] py-3 pl-4 pr-3">
          <p className="font-mono text-[10px] font-bold uppercase tracking-[0.2em] text-accent">
            Cómo mejorarlo
          </p>
          <p className="mt-1.5 text-[15px] font-semibold leading-relaxed text-ink">
            {m.suggestion}
          </p>
        </div>
      )}
    </article>
  );
}

export function ImprovementsList({ items }: ImprovementsListProps) {
  if (items.length === 0) {
    return (
      <p className="text-sm text-ink-soft">
        No detectamos mejoras prioritarias en esta sesión.
      </p>
    );
  }

  const sorted = [...items].sort(
    (a, b) => priorityOrder(a.priority) - priorityOrder(b.priority),
  );

  return (
    <div className="flex flex-col gap-4">
      {sorted.map((m, i) => (
        <ImprovementCard key={i} m={m} index={i} />
      ))}
    </div>
  );
}
