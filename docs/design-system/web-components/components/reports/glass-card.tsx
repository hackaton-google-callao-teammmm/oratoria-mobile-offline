import type { ReactNode } from "react";

/**
 * Frosted-glass card with a soft, slowly-drifting coloured blob glowing behind
 * the pane. The `tone` sets the blob colour (semantic: positivity / priority);
 * `index` desynchronises each card's blob so a column of them doesn't move in
 * lockstep. Content is rendered on the frosted pane and stays fully legible.
 */
export type GlassTone = "emerald" | "red" | "amber" | "sky";

const BLOB_COLOR: Record<GlassTone, string> = {
  emerald: "#34d399",
  red: "#fb7185",
  amber: "#fbbf24",
  sky: "#38bdf8",
};

export function GlassCard({
  tone,
  index = 0,
  children,
}: {
  tone: GlassTone;
  index?: number;
  children: ReactNode;
}) {
  return (
    <div className="glass-card">
      <span
        className="glass-card__blob"
        style={{
          backgroundColor: BLOB_COLOR[tone],
          // negative delay → each card starts at a different phase of the loop
          animationDelay: `${(index % 4) * -1.7}s`,
        }}
        aria-hidden
      />
      <div className="glass-card__pane">{children}</div>
    </div>
  );
}
