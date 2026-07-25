/** Raycast-style dark backdrop for the auth panels: bright neon-green light
 * "blades" plus a few crisp streaks, drifting over a near-black stage with film
 * grain. Purely decorative and animated; the cards on top stay static. */
import type { CSSProperties } from "react";

type Blade = {
  left: string;
  width: string;
  blur: string;
  dur: string;
  dx: string;
  dy: string;
  opacity: number;
  color: string;
};

const ROT = "-31deg";

// Phosphorescent greens (#39FF14 / #CCFF00 / #99FF33). The hottest, widest
// blade sits centre; thin crisp streaks add Raycast's sharp bright edges.
// Generous drift so the field clearly moves.
const BLADES: Blade[] = [
  {
    left: "14%",
    width: "6%",
    blur: "30px",
    dur: "13s",
    dx: "8%",
    dy: "-6%",
    opacity: 0.55,
    color: "#99FF33",
  },
  {
    left: "29%",
    width: "11%",
    blur: "34px",
    dur: "11s",
    dx: "10%",
    dy: "-7%",
    opacity: 0.85,
    color: "#39FF14",
  },
  {
    left: "45%",
    width: "15%",
    blur: "30px",
    dur: "16s",
    dx: "-8%",
    dy: "6%",
    opacity: 1,
    color: "#CCFF00",
  },
  {
    left: "61%",
    width: "10%",
    blur: "34px",
    dur: "12s",
    dx: "9%",
    dy: "-6%",
    opacity: 0.85,
    color: "#39FF14",
  },
  {
    left: "76%",
    width: "7%",
    blur: "38px",
    dur: "18s",
    dx: "-7%",
    dy: "7%",
    opacity: 0.55,
    color: "#19A80B",
  },
  {
    left: "88%",
    width: "4%",
    blur: "44px",
    dur: "15s",
    dx: "8%",
    dy: "-5%",
    opacity: 0.4,
    color: "#99FF14",
  },
];

// Thin, low-blur streaks = the crisp bright edges in Raycast's hero.
const STREAKS: Blade[] = [
  {
    left: "37%",
    width: "1.4%",
    blur: "5px",
    dur: "14s",
    dx: "9%",
    dy: "-6%",
    opacity: 0.9,
    color: "#E7FF8A",
  },
  {
    left: "55%",
    width: "1.1%",
    blur: "4px",
    dur: "12s",
    dx: "-7%",
    dy: "5%",
    opacity: 0.8,
    color: "#CCFF00",
  },
  {
    left: "69%",
    width: "1.6%",
    blur: "6px",
    dur: "17s",
    dx: "8%",
    dy: "-5%",
    opacity: 0.7,
    color: "#39FF14",
  },
];

function bladeStyle(b: Blade): CSSProperties {
  return {
    left: b.left,
    width: b.width,
    opacity: b.opacity,
    background: `linear-gradient(180deg, transparent 0%, ${b.color} 42%, ${b.color} 60%, transparent 100%)`,
    "--blade-rot": ROT,
    "--blade-blur": b.blur,
    "--blade-dur": b.dur,
    "--blade-dx": b.dx,
    "--blade-dy": b.dy,
  } as CSSProperties;
}

export function AuthBackdrop() {
  return (
    <div
      aria-hidden
      className="absolute inset-0 overflow-hidden"
      style={{
        background:
          "radial-gradient(135% 95% at 62% 22%, #15240b 0%, #0a0f06 44%, #030502 100%)",
      }}
    >
      {BLADES.map((b, i) => (
        <div key={`b${i}`} className="auth-blade" style={bladeStyle(b)} />
      ))}
      {STREAKS.map((s, i) => (
        <div key={`s${i}`} className="auth-blade" style={bladeStyle(s)} />
      ))}
      {/* Bright neon bloom top-right + bottom vignette for depth. */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(55% 38% at 66% 16%, rgba(57,255,20,0.28), transparent 70%), linear-gradient(to bottom, transparent 50%, rgba(0,0,0,0.5) 100%)",
        }}
      />
      <div className="auth-grain" />
    </div>
  );
}
