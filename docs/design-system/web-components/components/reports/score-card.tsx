import { useEffect, useState } from "react";

interface ScoreCardProps {
  score: number;
  size?: "md" | "lg";
  animate?: boolean;
}

const COUNT_DURATION_MS = 1200;

export function ScoreCard({
  score,
  size = "lg",
  animate = true,
}: ScoreCardProps) {
  const clamped = Math.max(0, Math.min(100, Math.round(score)));
  const [displayed, setDisplayed] = useState(animate ? 0 : clamped);

  useEffect(() => {
    if (!animate) {
      setDisplayed(clamped);
      return;
    }
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / COUNT_DURATION_MS);
      const eased = 1 - Math.pow(1 - t, 3);
      setDisplayed(Math.round((clamped) * eased));
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [animate, clamped]);

  const isHigh = clamped >= 70;
  const numCls = size === "lg" ? "text-8xl sm:text-9xl" : "text-6xl";

  return (
    <div
      className="flex items-baseline gap-2"
      role="img"
      aria-label={`Score ${clamped} de 100`}
    >
      <span
        className={`font-display font-bold leading-none tracking-tight tabular-nums ${numCls} ${isHigh ? "text-accent" : "text-ink"}`}
      >
        {displayed}
      </span>
      <span className="text-xl font-medium text-ink-faint">/ 100</span>
    </div>
  );
}
