/** Animated lime orb — equalizer core + expanding rings. Light-mode adapted. */

import { cn } from "@/lib/utils";

export type OrbState = "idle" | "listening" | "processing";

const RING_KEYFRAMES = `
  @keyframes oratoria-orb-ring {
    0% { transform: scale(0.85); opacity: 0.7; }
    100% { transform: scale(1.45); opacity: 0; }
  }
  @keyframes oratoria-orb-eq {
    0%, 100% { transform: scaleY(0.4); }
    50% { transform: scaleY(1.2); }
  }
  @keyframes oratoria-orb-pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(0.94); }
  }
`;

interface AudioOrbProps {
  state: OrbState;
  size?: number;
}

export function AudioOrb({ state, size = 220 }: AudioOrbProps) {
  const coreSize = Math.round(size * 0.58);
  const idle = state === "idle";
  return (
    <div
      className="relative grid place-items-center"
      style={{ width: size, height: size }}
    >
      <style>{RING_KEYFRAMES}</style>
      {/* Soft halo */}
      <div
        aria-hidden
        className="absolute inset-0 rounded-full"
        style={{
          background:
            "radial-gradient(circle at 35% 35%, rgba(198,255,61,0.55), rgba(198,255,61,0.12) 60%, transparent 80%)",
          opacity: idle ? 0.5 : 1,
          transition: "opacity 300ms",
        }}
      />
      {/* Expanding rings — only while not idle */}
      {!idle && (
        <>
          <span
            aria-hidden
            className="absolute inset-0 rounded-full border border-[#C6FF3D]/60"
            style={{ animation: "oratoria-orb-ring 3s ease-out infinite" }}
          />
          <span
            aria-hidden
            className="absolute inset-0 rounded-full border border-[#C6FF3D]/40"
            style={{
              animation: "oratoria-orb-ring 3s ease-out infinite",
              animationDelay: "1.5s",
            }}
          />
        </>
      )}
      {/* Lime core */}
      <div
        className={cn(
          "relative grid place-items-center rounded-full shadow-[0_0_60px_rgba(198,255,61,0.45)]",
          state === "processing" && "animate-[oratoria-orb-pulse_2.5s_ease-in-out_infinite]",
        )}
        style={{
          width: coreSize,
          height: coreSize,
          background: "linear-gradient(135deg, #C6FF3D 0%, #9CCC1F 100%)",
        }}
      >
        <Equalizer active={state === "listening" || state === "processing"} />
      </div>
    </div>
  );
}

function Equalizer({ active }: { active: boolean }) {
  const heights = [22, 44, 60, 36, 22];
  return (
    <div className="flex items-center gap-[5px]">
      {heights.map((h, i) => (
        <span
          key={i}
          className="w-1.5 rounded-sm bg-[#0A0A0A]"
          style={{
            height: `${h}px`,
            animation: active
              ? "oratoria-orb-eq 1.2s ease-in-out infinite"
              : "none",
            animationDelay: `${i * 0.15}s`,
            transformOrigin: "center",
          }}
        />
      ))}
    </div>
  );
}
