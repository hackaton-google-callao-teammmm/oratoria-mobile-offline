/**
 * Structured pitch — "así te habría quedado mejor". Renders the restructured,
 * better-told version of what the user said: a headline, the narrative beats in
 * order, and a delivery note tied to how they spoke.
 */
import { Sparkles, Volume2 } from "lucide-react";

import type { StructuredPitch } from "@/lib/api/sessions";

export function StructuredPitchSection({ pitch }: { pitch: StructuredPitch }) {
  return (
    <div className="rounded-2xl border border-accent/20 bg-surface/70 p-6 sm:p-7">
      <div className="flex items-center gap-2 text-accent">
        <Sparkles className="h-4 w-4" strokeWidth={2.2} aria-hidden />
        <span className="text-[11px] font-semibold uppercase tracking-[0.16em]">
          Tu idea, mejor contada
        </span>
      </div>

      <p className="font-display mt-3 text-xl font-bold leading-snug text-ink sm:text-2xl">
        “{pitch.headline}”
      </p>

      <ol className="mt-6 flex flex-col gap-4">
        {pitch.sections.map((section, i) => (
          <li key={i} className="relative flex gap-4">
            <div className="flex flex-col items-center">
              <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-lime text-[11px] font-bold text-on-lime">
                {i + 1}
              </span>
              {i < pitch.sections.length - 1 && (
                <span className="mt-1 w-px flex-1 bg-line" aria-hidden />
              )}
            </div>
            <div className="flex-1 pb-1">
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-faint">
                {section.label}
              </p>
              <p className="mt-1.5 text-[14px] leading-relaxed text-ink-soft">
                {section.content}
              </p>
            </div>
          </li>
        ))}
      </ol>

      {pitch.delivery_note && (
        <div className="mt-6 flex items-start gap-3 rounded-xl border border-line bg-surface px-4 py-3.5">
          <Volume2
            className="mt-0.5 h-4 w-4 shrink-0 text-accent"
            strokeWidth={2}
            aria-hidden
          />
          <p className="text-[13px] leading-relaxed text-ink-soft">
            <span className="font-semibold text-ink">Cómo decirlo: </span>
            {pitch.delivery_note}
          </p>
        </div>
      )}
    </div>
  );
}
