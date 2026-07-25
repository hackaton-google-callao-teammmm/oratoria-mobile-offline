import { humanizeEvidence } from "@/lib/reports/format";

export type Dimension = "verbal" | "paraverbal" | "strategic";

export interface Strength {
  title: string;
  description?: string;
  dimension?: Dimension | string;
  evidence?: string;
  impact?: string;
}

export const DIMENSION_META: Record<string, { label: string }> = {
  verbal: { label: "Verbal" },
  paraverbal: { label: "Paraverbal" },
  strategic: { label: "Estratégica" },
};

interface StrengthsListProps {
  items: Strength[];
}

/**
 * Editorial "scouting-sheet" card with deliberate hierarchy and brand life:
 * a lime kicker rule, a large brand-coloured index numeral, a bold display
 * title (the focal point), and section labels in monospace. No emoji, no
 * pills, no glass — the brand colour earns its place on the numeral and the
 * actionable accent, not on decoration.
 */
export function StrengthCard({
  s,
  index = 0,
}: {
  s: Strength;
  index?: number;
}) {
  const meta = s.dimension ? DIMENSION_META[s.dimension] : undefined;
  const num = String(index + 1).padStart(2, "0");

  return (
    <article className="relative isolate overflow-hidden rounded-lg border border-line bg-surface p-6 sm:p-8">
      {/* Layered brand "target" motif in the corner — crisp concentric rings
          (not a blurred blob), clipped to arcs by the card, behind the text. */}
      <div
        aria-hidden
        className="pointer-events-none absolute right-0 top-0 -z-10"
      >
        <span className="absolute -right-16 -top-16 h-44 w-44 rounded-full bg-lime/[0.08]" />
        <span className="absolute -right-9 -top-9 h-28 w-28 rounded-full bg-lime/[0.16]" />
        <span className="absolute -right-2 -top-2 h-16 w-16 rounded-full bg-lime/[0.24]" />
      </div>

      {/* Brand-coloured index numeral — accent reads deep-green on light, lime
          on dark (both legible), so it stays branded without going pale. */}
      <span
        aria-hidden
        className="font-display pointer-events-none absolute right-5 top-2 z-[1] select-none text-7xl font-black leading-none tracking-tighter text-accent/70"
      >
        {num}
      </span>

      {/* lime kicker rule */}
      <div className="h-[3px] w-9 rounded-full bg-lime" />

      <p className="font-mono mt-3 text-[10px] font-medium uppercase tracking-[0.24em] text-ink-faint">
        Fortaleza{meta ? ` · ${meta.label}` : ""}
      </p>

      <h3 className="font-display relative mt-2 max-w-[28ch] text-2xl font-bold leading-[1.12] tracking-tight text-ink sm:text-[26px]">
        {s.title}
      </h3>

      {s.description && (
        <p className="mt-3.5 max-w-prose text-[15px] leading-relaxed text-ink-soft">
          {s.description}
        </p>
      )}

      {s.evidence && (
        <div className="mt-6 border-l-2 border-line pl-4">
          <p className="font-mono text-[10px] font-medium uppercase tracking-[0.2em] text-ink-faint">
            Evidencia
          </p>
          <p className="mt-1.5 text-[15px] italic leading-relaxed text-ink-soft">
            {humanizeEvidence(s.evidence)}
          </p>
        </div>
      )}

      {s.impact && (
        <div className="mt-6 border-t border-line pt-4">
          <p className="font-mono text-[10px] font-medium uppercase tracking-[0.2em] text-ink-faint">
            Por qué importa
          </p>
          <p className="mt-1.5 text-[15px] font-medium leading-relaxed text-ink">
            {s.impact}
          </p>
        </div>
      )}
    </article>
  );
}

export function StrengthsList({ items }: StrengthsListProps) {
  if (items.length === 0) {
    return (
      <p className="text-sm text-ink-soft">
        No detectamos fortalezas claras en esta sesión.
      </p>
    );
  }
  return (
    <div className="flex flex-col gap-4">
      {items.map((s, i) => (
        <StrengthCard key={i} s={s} index={i} />
      ))}
    </div>
  );
}
