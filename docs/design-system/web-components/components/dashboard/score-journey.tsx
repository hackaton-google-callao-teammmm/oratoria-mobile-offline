/**
 * Score Journey — the user's improvement trajectory as an animated area
 * chart instead of a repetitive list. Each completed session is a point
 * on the curve (clickable → its report); GSAP draws the line on mount.
 * Domain-first: a speaker's progress is a story, not a table.
 */
import { Link } from "@tanstack/react-router";
import gsap from "gsap";
import { TrendingUp } from "lucide-react";
import { useEffect, useLayoutEffect, useRef } from "react";

import type { SessionSummary } from "@/lib/api/sessions";

const useIsoLayoutEffect =
  typeof window !== "undefined" ? useLayoutEffect : useEffect;

const VB_W = 1000;
const VB_H = 280;
const PAD_X = 26;
const PAD_TOP = 28;
const PAD_BOT = 30;

interface Pt {
  x: number;
  y: number;
  xPct: number;
  yPct: number;
  score: number;
  label: string;
  id: string;
}

function shortLabel(s: SessionSummary): string {
  const ctx = s.context as { presentation_type?: unknown };
  const raw = typeof ctx?.presentation_type === "string" ? ctx.presentation_type : "";
  const base = raw || (s.type === "async" ? "Asíncrona" : "En vivo");
  const w = base.split(" ")[0];
  return w.length > 10 ? `${w.slice(0, 9)}…` : w;
}

function smoothPath(pts: Pt[]): string {
  if (pts.length < 2) return "";
  const d: string[] = [`M ${pts[0].x} ${pts[0].y}`];
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i === 0 ? 0 : i - 1];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[i + 2 < pts.length ? i + 2 : i + 1];
    const c1x = p1.x + (p2.x - p0.x) / 6;
    const c1y = p1.y + (p2.y - p0.y) / 6;
    const c2x = p2.x - (p3.x - p1.x) / 6;
    const c2y = p2.y - (p3.y - p1.y) / 6;
    d.push(`C ${c1x} ${c1y}, ${c2x} ${c2y}, ${p2.x} ${p2.y}`);
  }
  return d.join(" ");
}

export function ScoreJourney({ sessions }: { sessions: SessionSummary[] }) {
  const lineRef = useRef<SVGPathElement>(null);
  const rootRef = useRef<HTMLDivElement>(null);

  const completed = sessions
    .filter((s) => s.status === "completed" && s.score !== null)
    .slice()
    .sort(
      (a, b) =>
        new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
    );

  const scores = completed.map((s) => s.score as number);
  const lo = Math.max(0, Math.min(...scores) - 5);
  const hi = Math.min(100, Math.max(...scores) + 5);
  const span = Math.max(1, hi - lo);

  const pts: Pt[] = completed.map((s, i) => {
    const xFrac = completed.length === 1 ? 0.5 : i / (completed.length - 1);
    const yFrac = ((s.score as number) - lo) / span;
    const x = PAD_X + xFrac * (VB_W - PAD_X * 2);
    const y = PAD_TOP + (1 - yFrac) * (VB_H - PAD_TOP - PAD_BOT);
    return {
      x,
      y,
      xPct: (x / VB_W) * 100,
      yPct: (y / VB_H) * 100,
      score: s.score as number,
      label: shortLabel(s),
      id: s.id,
    };
  });

  const line = smoothPath(pts);
  const area =
    pts.length >= 2
      ? `${line} L ${pts[pts.length - 1].x} ${VB_H - PAD_BOT} L ${pts[0].x} ${VB_H - PAD_BOT} Z`
      : "";

  const first = scores[0] ?? 0;
  const current = scores[scores.length - 1] ?? 0;
  const delta = current - first;
  const best = scores.length ? Math.max(...scores) : 0;

  useIsoLayoutEffect(() => {
    const root = rootRef.current;
    const path = lineRef.current;
    if (!root || !path) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const ctx = gsap.context(() => {
      const len = path.getTotalLength();
      gsap.set(path, { strokeDasharray: len, strokeDashoffset: len });
      const tl = gsap.timeline();
      tl.to(path, { strokeDashoffset: 0, duration: 1.3, ease: "power2.inOut" })
        .from(
          root.querySelectorAll("[data-journey-area]"),
          { opacity: 0, duration: 0.8 },
          0.2,
        )
        .from(
          root.querySelectorAll("[data-journey-pt]"),
          {
            scale: 0,
            opacity: 0,
            transformOrigin: "center",
            stagger: 0.07,
            duration: 0.4,
            ease: "back.out(2)",
            clearProps: "transform,opacity",
          },
          0.7,
        );
    }, root);
    return () => ctx.revert();
  }, [line]);

  if (pts.length < 2) {
    return (
      <div className="rounded-2xl bg-surface p-6 text-sm text-ink-soft">
        Completá un par de sesiones para ver tu progresión.
      </div>
    );
  }

  return (
    <div ref={rootRef} className="rounded-2xl bg-surface p-6 sm:p-7">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <div className="flex items-baseline gap-2.5">
            <span className="font-display text-5xl font-bold leading-none tabular-nums text-ink">
              {current}
            </span>
            <span
              className={`inline-flex items-center gap-1 text-sm font-semibold ${
                delta >= 0 ? "text-accent" : "text-red-400"
              }`}
            >
              <TrendingUp className="h-4 w-4" strokeWidth={2.2} />
              {delta >= 0 ? "+" : ""}
              {delta} pts
            </span>
          </div>
          <p className="mt-1.5 text-[13px] text-ink-soft">
            Tu score a lo largo de {completed.length} sesiones · mejor:{" "}
            <span className="font-semibold text-ink">{best}</span>
          </p>
        </div>
      </div>

      <div className="relative mt-6 h-56 w-full">
        <svg
          viewBox={`0 0 ${VB_W} ${VB_H}`}
          preserveAspectRatio="none"
          className="absolute inset-0 h-full w-full"
        >
          <defs>
            <linearGradient id="journey-fill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--color-accent)" stopOpacity="0.28" />
              <stop offset="100%" stopColor="var(--color-accent)" stopOpacity="0" />
            </linearGradient>
          </defs>
          {[0.25, 0.5, 0.75].map((g) => (
            <line
              key={g}
              x1="0"
              x2={VB_W}
              y1={PAD_TOP + g * (VB_H - PAD_TOP - PAD_BOT)}
              y2={PAD_TOP + g * (VB_H - PAD_TOP - PAD_BOT)}
              stroke="var(--color-line)"
              strokeWidth="1"
            />
          ))}
          <path d={area} fill="url(#journey-fill)" data-journey-area />
          <path
            ref={lineRef}
            d={line}
            fill="none"
            stroke="var(--color-accent)"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
            vectorEffect="non-scaling-stroke"
          />
        </svg>

        {/* Interactive points overlaid as crisp HTML */}
        {pts.map((p, i) => {
          const isLast = i === pts.length - 1;
          return (
            <Link
              key={p.id}
              to="/reports/$reportId"
              params={{ reportId: p.id }}
              className="group absolute -translate-x-1/2 -translate-y-1/2"
              style={{ left: `${p.xPct}%`, top: `${p.yPct}%` }}
            >
              <span
                data-journey-pt
                className={`block rounded-full border-2 border-stage bg-accent transition-transform group-hover:scale-125 ${
                  isLast ? "h-3.5 w-3.5 ring-4 ring-accent/20" : "h-2.5 w-2.5"
                }`}
              />
              <span className="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 hidden -translate-x-1/2 whitespace-nowrap rounded-md bg-ink px-2 py-1 text-[11px] font-semibold text-stage group-hover:block">
                {p.label} · {p.score}
              </span>
            </Link>
          );
        })}
      </div>

      <div className="mt-3 flex justify-between px-1 text-[11px] text-ink-faint">
        {pts.map((p) => (
          <span key={p.id} className="flex-1 truncate text-center first:text-left last:text-right">
            {p.label}
          </span>
        ))}
      </div>
    </div>
  );
}
