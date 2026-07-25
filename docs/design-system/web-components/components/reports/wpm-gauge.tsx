import { useEffect, useState } from "react";

const CX = 120;
const CY = 120;
const RADIUS = 100;
const MAX_WPM = 220;

function gaugePoint(f: number, r = RADIUS, cx = CX, cy = CY) {
  const angle = Math.PI * (1 - f);
  return {
    x: cx + r * Math.cos(angle),
    y: cy - r * Math.sin(angle),
  };
}

function zonePath(f1: number, f2: number): string {
  const a = gaugePoint(f1);
  const b = gaugePoint(f2);
  const largeArc = f2 - f1 > 0.5 ? 1 : 0;
  return `M ${a.x.toFixed(3)} ${a.y.toFixed(3)} A ${RADIUS} ${RADIUS} 0 ${largeArc} 0 ${b.x.toFixed(3)} ${b.y.toFixed(3)}`;
}

// Zone boundaries as fractions of 0..1 (mapped over 0..MAX_WPM)
const ZONE_SLOW_END = 90 / MAX_WPM; // 0..90 wpm = Lento
const ZONE_IDEAL_END = 170 / MAX_WPM; // 90..170 wpm = Ideal

function wpmZone(wpm: number | null): {
  label: string;
  colorClass: string;
} {
  if (wpm === null) return { label: "Sin datos", colorClass: "text-ink-faint" };
  if (wpm < 90) return { label: "Lento", colorClass: "text-amber-500" };
  if (wpm <= 170) return { label: "Ideal", colorClass: "text-emerald-500" };
  return { label: "Muy rápido", colorClass: "text-red-500" };
}

export function WpmGauge({ wpm }: { wpm: number | null }) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setReady(true), 50);
    return () => clearTimeout(timer);
  }, []);

  const clamped = wpm !== null ? Math.max(0, Math.min(MAX_WPM, wpm)) : 0;
  const f = clamped / MAX_WPM;
  // Rotation: at f=0 needle points left (0deg), at f=1 needle points right (180deg)
  const rotateDeg = ready && wpm !== null ? f * 180 : 0;

  const { label, colorClass } = wpmZone(wpm);

  // Needle tip and base when pointing LEFT (f=0), before rotation
  const needleTip = { x: CX - 88, y: CY }; // left
  const needleBase = { x: CX + 12, y: CY }; // small counterweight right

  return (
    <div
      className="flex flex-col items-center"
      role="img"
      aria-label={
        wpm !== null
          ? `Velocidad de habla ${wpm} palabras por minuto`
          : "Velocidad de habla sin datos"
      }
    >
      <svg
        viewBox="0 0 240 130"
        width="100%"
        style={{ maxWidth: 240 }}
        aria-hidden
      >
        {/* Background track: top semicircle, sweep=0 (CCW in SVG = up through top) */}
        <path
          d="M 20 120 A 100 100 0 0 0 220 120"
          fill="none"
          stroke="currentColor"
          strokeWidth="14"
          strokeLinecap="round"
          className="text-line"
        />

        {/* Zone arcs */}
        {/* Slow: 0→90 wpm (amber) */}
        <path
          d={zonePath(0, ZONE_SLOW_END)}
          fill="none"
          strokeWidth="14"
          strokeLinecap="round"
          className="stroke-amber-500"
        />
        {/* Ideal: 90→170 wpm (emerald) */}
        <path
          d={zonePath(ZONE_SLOW_END, ZONE_IDEAL_END)}
          fill="none"
          strokeWidth="14"
          strokeLinecap="round"
          className="stroke-emerald-500"
        />
        {/* Fast: 170→220 wpm (red) */}
        <path
          d={zonePath(ZONE_IDEAL_END, 1)}
          fill="none"
          strokeWidth="14"
          strokeLinecap="round"
          className="stroke-red-500"
        />

        {/* Needle group — rotates around center (CX, CY) */}
        <g
          style={{
            transformOrigin: `${CX}px ${CY}px`,
            transform: `rotate(${rotateDeg}deg)`,
            transition: ready ? "transform 800ms ease-out" : "none",
          }}
        >
          <line
            x1={needleBase.x}
            y1={needleBase.y}
            x2={needleTip.x}
            y2={needleTip.y}
            stroke="currentColor"
            strokeWidth="3"
            strokeLinecap="round"
            className="text-ink"
          />
        </g>

        {/* Center dot */}
        <circle cx={CX} cy={CY} r="5" className="fill-ink" />
      </svg>

      {/* Value + zone label */}
      <div className="mt-2 flex flex-col items-center gap-0.5">
        <span className={`font-display text-3xl font-bold text-ink`}>
          {wpm !== null ? Math.round(wpm) : "—"}
        </span>
        <span className={`text-xs font-semibold ${colorClass}`}>{label}</span>
        <span className="text-[10px] uppercase tracking-wider text-ink-faint">
          Palabras / min
        </span>
      </div>
    </div>
  );
}
