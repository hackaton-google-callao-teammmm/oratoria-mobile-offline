/** Right-hand visual panel for the LOGIN screen — branded artwork + animated
 * showcase cards (live equalizer, self-filling score, rotating lime glow). */
import { useEffect, useState } from "react";

import { AuthBackdrop } from "./auth-backdrop";

function prefersReducedMotion() {
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

/** Eases a number from 0 to `target` on mount (easeOutCubic). Honors
 * reduced-motion by jumping straight to the target. */
function useCountUp(target: number, duration = 1300) {
  const [value, setValue] = useState(0);
  useEffect(() => {
    if (prefersReducedMotion()) {
      setValue(target);
      return;
    }
    let raf = 0;
    let start = 0;
    const tick = (now: number) => {
      if (!start) start = now;
      const p = Math.min(1, (now - start) / duration);
      const eased = 1 - (1 - p) ** 3;
      setValue(Math.round(target * eased));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, duration]);
  return value;
}

export function AuthVisualLogin() {
  return (
    <aside className="relative hidden flex-col justify-center overflow-hidden p-12 lg:flex">
      <AuthBackdrop />
      {/* Legibility scrim: calms the centre band so text/cards read clearly
          while the neon keeps glowing at the edges. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(78%_64%_at_50%_50%,rgba(3,6,2,0.66),transparent_80%)]"
      />

      <div className="relative z-10 mx-auto flex w-full max-w-sm flex-col gap-8">
        <header className="text-center">
          <h2 className="text-balance text-[32px] font-bold leading-[1.12] tracking-tight text-white drop-shadow-[0_2px_12px_rgba(0,0,0,0.55)]">
            Tu escenario para{" "}
            <span className="text-[#C6FF3D]">hablar mejor</span>
          </h2>
          <p className="mx-auto mt-3 max-w-xs text-[14px] leading-relaxed text-white/75">
            Practica, mide tu progreso y gana confianza con un coach de IA que
            te escucha 24/7.
          </p>
        </header>
        <ProgressMockup />
        <QuoteCard />
      </div>
    </aside>
  );
}

// A real voice-waveform shape. The score "lights up" the wave from the left,
// turning the generic progress bar into the product's own audio language.
const WAVEFORM = [
  28, 44, 62, 38, 74, 92, 54, 34, 50, 82, 100, 70, 44, 30, 56, 86, 96, 60, 40,
  26, 52, 72, 90, 64, 42, 30, 58, 80, 94, 68, 48, 34, 52, 78, 90, 62, 40, 28,
  46, 70,
];

function ProgressMockup() {
  const score = useCountUp(87);
  const lit = Math.round((WAVEFORM.length * score) / 100);
  return (
    <div className="auth-card p-6">
      <div className="flex items-center gap-3">
        <div className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#C6FF3D] shadow-[0_0_22px_rgba(57,255,20,0.5)]">
          <Equalizer scale={0.65} />
        </div>
        <div className="min-w-0">
          <div className="text-[14px] font-bold text-white">Hola, María</div>
          <div className="text-[12px] text-white/60">
            racha de 6 días · 14 sesiones
          </div>
        </div>
      </div>

      <div className="mt-6">
        <div className="text-[10px] font-semibold uppercase tracking-[0.16em] text-white/55">
          Score global
        </div>
        <div className="mt-1 flex items-baseline gap-1.5">
          <span className="font-display text-[46px] font-bold leading-none tabular-nums text-white">
            {score}
          </span>
          <span className="text-sm text-white/45">/ 100</span>
        </div>
      </div>

      <div className="mt-4 flex h-12 items-center gap-[3px]">
        {WAVEFORM.map((h, i) => (
          <span
            key={i}
            className="flex-1 rounded-full"
            style={{
              height: `${h}%`,
              background:
                i < lit
                  ? "linear-gradient(to top, #19A80B, #39FF14)"
                  : "rgba(255,255,255,0.12)",
              boxShadow: i < lit ? "0 0 6px rgba(57,255,20,0.45)" : "none",
            }}
          />
        ))}
      </div>

      <p className="mt-5 text-[12px] text-white/60">
        Próxima lección:{" "}
        <strong className="font-semibold text-white">
          Pausas intencionales · 4 de 7
        </strong>
      </p>
    </div>
  );
}

function Equalizer({ scale = 1 }: { scale?: number }) {
  const heights = [14, 22, 30, 22, 14];
  return (
    <div
      className="flex items-center gap-[3px]"
      style={{ transform: `scale(${scale})` }}
    >
      {heights.map((h, i) => (
        <span
          key={i}
          className="eq-bar w-1 rounded-sm bg-[#0A0A0A]"
          style={{ height: `${h}px`, animationDelay: `${i * 0.13}s` }}
        />
      ))}
    </div>
  );
}

function QuoteCard() {
  return (
    <figure className="relative pl-5">
      <span
        aria-hidden
        className="absolute bottom-1.5 left-0 top-1.5 w-[3px] rounded-full bg-gradient-to-b from-[#39FF14] to-[#39FF14]/0"
      />
      <p className="text-[15px] font-medium leading-relaxed text-white/90">
        Pasé de tartamudear en mis pitches a cerrar mi primera ronda de
        inversión.
      </p>
      <figcaption className="mt-3 flex items-center gap-2.5">
        <img
          src="/testimonial-maria.jpg"
          alt="María González"
          className="h-9 w-9 shrink-0 rounded-full object-cover ring-1 ring-white/15"
        />
        <div>
          <div className="text-[13px] font-bold text-white">María González</div>
          <div className="text-[11px] text-white/55">CEO · Fintech LATAM</div>
        </div>
      </figcaption>
    </figure>
  );
}
