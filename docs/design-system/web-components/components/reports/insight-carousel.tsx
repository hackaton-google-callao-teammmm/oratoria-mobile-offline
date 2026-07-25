import { ChevronLeft, ChevronRight } from "lucide-react";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";

/**
 * Lightweight, dependency-free carousel for the report's strengths +
 * improvements. Shows ONE card at a time (so the screen never feels saturated)
 * with prev/next buttons, dot pagination, a counter, keyboard arrows and touch
 * swipe. Each slide animates in from the side it came from.
 */
export interface InsightSlide {
  key: string;
  kind: "strength" | "improvement";
  node: ReactNode;
}

export function InsightCarousel({ slides }: { slides: InsightSlide[] }) {
  const n = slides.length;
  const [i, setI] = useState(0);
  const [dir, setDir] = useState<1 | -1>(1);

  const go = useCallback(
    (d: 1 | -1) => {
      setDir(d);
      setI((p) => (p + d + n) % n);
    },
    [n],
  );

  const jump = useCallback(
    (target: number) => {
      setDir(target >= i ? 1 : -1);
      setI(target);
    },
    [i],
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "ArrowLeft") go(-1);
      else if (e.key === "ArrowRight") go(1);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [go]);

  // Touch / pointer swipe
  const startX = useRef<number | null>(null);
  const onPointerDown = (e: React.PointerEvent) => {
    startX.current = e.clientX;
  };
  const onPointerUp = (e: React.PointerEvent) => {
    if (startX.current === null) return;
    const dx = e.clientX - startX.current;
    startX.current = null;
    if (Math.abs(dx) > 50) go(dx < 0 ? 1 : -1);
  };

  if (n === 0) {
    return (
      <p className="text-sm text-ink-soft">
        No hay observaciones para mostrar.
      </p>
    );
  }

  const slide = slides[i];

  return (
    <div className="mx-auto w-full max-w-2xl">
      {/* Controls bar — a plain monospace counter, no coloured pill */}
      <div className="mb-4 flex items-center justify-between gap-3">
        <span className="font-mono text-xs tabular-nums tracking-[0.18em] text-ink-faint">
          {String(i + 1).padStart(2, "0")} / {String(n).padStart(2, "0")}
        </span>

        <div className="flex items-center gap-2">
          <NavBtn label="Anterior" onClick={() => go(-1)}>
            <ChevronLeft className="h-4 w-4" strokeWidth={2.5} />
          </NavBtn>
          <NavBtn label="Siguiente" onClick={() => go(1)}>
            <ChevronRight className="h-4 w-4" strokeWidth={2.5} />
          </NavBtn>
        </div>
      </div>

      {/* Viewport — one slide, re-keyed so the enter animation replays */}
      <div
        className="overflow-hidden"
        onPointerDown={onPointerDown}
        onPointerUp={onPointerUp}
      >
        <div
          key={i}
          className={
            dir === 1
              ? "animate-in fade-in slide-in-from-right-8 duration-300 ease-out"
              : "animate-in fade-in slide-in-from-left-8 duration-300 ease-out"
          }
        >
          {slide.node}
        </div>
      </div>

      {/* Dot pagination */}
      <div className="mt-5 flex flex-wrap items-center justify-center gap-2">
        {slides.map((s, idx) => (
          <button
            key={s.key}
            type="button"
            onClick={() => jump(idx)}
            aria-label={`Ir a la observación ${idx + 1}`}
            aria-current={idx === i}
            className={`h-2 rounded-full transition-all ${
              idx === i
                ? "w-6 bg-accent"
                : "w-2 bg-line-strong hover:bg-ink-faint"
            }`}
          />
        ))}
      </div>
    </div>
  );
}

function NavBtn({
  label,
  onClick,
  children,
}: {
  label: string;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="grid h-9 w-9 place-items-center rounded-full border border-line bg-surface text-ink-soft transition-colors hover:border-line-strong hover:text-ink"
    >
      {children}
    </button>
  );
}
