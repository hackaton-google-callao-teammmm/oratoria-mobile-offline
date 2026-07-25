import { useEffect, useState } from "react";

const COUNT_DURATION_MS = 1200;
const RADIUS = 88;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

function arcColor(score: number): string {
  if (score < 50) return "text-red-500";
  if (score < 70) return "text-amber-500";
  return "text-accent";
}

function verdict(score: number): string {
  if (score >= 85) return "Excelente";
  if (score >= 70) return "Buena";
  if (score >= 50) return "En desarrollo";
  return "Bajo";
}

export function ScoreRing({ score }: { score: number }) {
  const clamped = Math.max(0, Math.min(100, Math.round(score)));
  const [displayed, setDisplayed] = useState(0);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / COUNT_DURATION_MS);
      const eased = 1 - Math.pow(1 - t, 3);
      setDisplayed(Math.round(clamped * eased));
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [clamped]);

  useEffect(() => {
    const timer = setTimeout(() => setReady(true), 50);
    return () => clearTimeout(timer);
  }, []);

  const colorClass = arcColor(clamped);
  const targetOffset = CIRCUMFERENCE * (1 - clamped / 100);
  const dashOffset = ready ? targetOffset : CIRCUMFERENCE;

  return (
    <div
      className="relative flex w-[220px] flex-col items-center"
      role="img"
      aria-label={`Puntuación ${clamped} de 100`}
    >
      <div className="relative h-[220px] w-[220px]">
        <svg width="220" height="220" viewBox="0 0 220 220" aria-hidden>
          {/* Background track */}
          <circle
            cx="110"
            cy="110"
            r={RADIUS}
            fill="none"
            stroke="currentColor"
            strokeWidth="14"
            className="text-line"
          />
          {/* Foreground arc */}
          <circle
            cx="110"
            cy="110"
            r={RADIUS}
            fill="none"
            stroke="currentColor"
            strokeWidth="14"
            strokeLinecap="round"
            strokeDasharray={CIRCUMFERENCE}
            strokeDashoffset={dashOffset}
            className={`${colorClass} transition-[stroke-dashoffset] duration-1000 ease-out`}
            transform="rotate(-90 110 110)"
          />
        </svg>

        {/* Centered number overlay */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span
            className={`font-display text-6xl font-bold tabular-nums leading-none ${colorClass}`}
          >
            {displayed}
          </span>
          <span className="mt-1 text-sm text-ink-faint">/100</span>
          <span className="mt-1.5 text-xs font-semibold uppercase tracking-wider text-ink-soft">
            {verdict(clamped)}
          </span>
        </div>
      </div>
    </div>
  );
}
