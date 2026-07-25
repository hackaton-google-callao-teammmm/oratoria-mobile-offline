/**
 * AuroraBackground — animated mesh-gradient backdrop (Raycast-inspired).
 *
 * A set of large, blurred, slowly-drifting color blobs in OratorIA's brand
 * palette (electric lime + analogous greens + a faint iridescent accent),
 * topped with a subtle SVG grain and a legibility fade so report text stays
 * readable on top. Purely decorative: `aria-hidden`, `pointer-events-none`.
 *
 * Must be placed inside a `relative isolate overflow-hidden` container; it
 * paints at `-z-10` within that container's stacking context, so it sits
 * behind the content but above the page surface — never over the sidebar.
 *
 * Motion respects `prefers-reduced-motion` (blobs freeze, grain stays).
 */

// Inline SVG grain (feTurbulence) — tiny, cached as a data URI.
const GRAIN_URI =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E";

export function AuroraBackground() {
  return (
    <div
      aria-hidden
      className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
    >
      {/* Drifting brand blobs */}
      <div
        className="aurora-blob aurora-1 absolute -left-[10%] -top-[15%] h-[44rem] w-[44rem] rounded-full blur-[90px]"
        style={{
          background:
            "radial-gradient(circle at center, rgba(198,255,61,0.55), rgba(198,255,61,0) 65%)",
        }}
      />
      <div
        className="aurora-blob aurora-2 absolute -right-[8%] top-[5%] h-[40rem] w-[40rem] rounded-full blur-[90px]"
        style={{
          background:
            "radial-gradient(circle at center, rgba(45,212,191,0.42), rgba(45,212,191,0) 65%)",
        }}
      />
      <div
        className="aurora-blob aurora-3 absolute left-[20%] top-[30%] h-[42rem] w-[42rem] rounded-full blur-[100px]"
        style={{
          background:
            "radial-gradient(circle at center, rgba(52,211,153,0.40), rgba(52,211,153,0) 65%)",
        }}
      />
      <div
        className="aurora-blob aurora-4 absolute right-[15%] bottom-[0%] h-[38rem] w-[38rem] rounded-full blur-[110px]"
        style={{
          background:
            "radial-gradient(circle at center, rgba(167,139,250,0.30), rgba(167,139,250,0) 70%)",
        }}
      />

      {/* Grain texture */}
      <div
        className="absolute inset-0 opacity-[0.04] mix-blend-overlay dark:opacity-[0.06]"
        style={{ backgroundImage: `url("${GRAIN_URI}")` }}
      />

      {/* Legibility fade — keeps content crisp over the color */}
      <div className="absolute inset-0 bg-gradient-to-b from-stage/50 via-stage/20 to-stage/70" />
    </div>
  );
}
