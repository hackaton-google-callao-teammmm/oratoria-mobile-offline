import { Link } from "@tanstack/react-router";
import { ArrowUpRight } from "lucide-react";

function greeting(now = new Date()) {
  const h = now.getHours();
  if (h < 12) return "Buenos días";
  if (h < 19) return "Buenas tardes";
  return "Buenas noches";
}

interface HeroCardProps {
  firstName: string;
  streakDays: number;
  weekDots: Array<"done" | "today" | "future">;
  weeklyCount: number;
  weeklyGoal: number;
}

/** Expressive mood, driven by the user's momentum (reference-style). */
function mood(streakDays: number, weeklyCount: number, weeklyGoal: number) {
  if (weeklyGoal > 0 && weeklyCount >= weeklyGoal)
    return { emoji: "🏆", label: "Meta cumplida" };
  if (streakDays >= 5) return { emoji: "🔥", label: "En racha" };
  if (weeklyCount > 0) return { emoji: "💪", label: "En forma" };
  return { emoji: "🎯", label: "Listo para arrancar" };
}

export function HeroCard({
  firstName,
  streakDays,
  weeklyCount,
  weeklyGoal,
}: HeroCardProps) {
  const remaining = Math.max(0, weeklyGoal - weeklyCount);
  const coachLine =
    remaining > 0
      ? `Vas ${weeklyCount} de ${weeklyGoal} sesiones esta semana. Entrá a una audiencia simulada que te escucha, te interrumpe y te exige en tiempo real.`
      : "Cumpliste tu semana. Hoy entrenamos a presión: audiencia simulada que te escucha, te interrumpe y te exige en tiempo real.";
  const m = mood(streakDays, weeklyCount, weeklyGoal);

  return (
    <section className="rounded-2xl bg-surface p-8 sm:p-10 lg:p-12">
      <div className="flex items-start justify-between gap-6">
        <p className="text-[15px] font-medium text-ink-soft">{greeting()},</p>
        <div className="flex items-center gap-3 text-right">
          <div>
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-faint">
              Estado
            </div>
            <div className="text-sm font-semibold text-ink">{m.label}</div>
          </div>
          <span className="text-4xl leading-none sm:text-5xl" aria-hidden>
            {m.emoji}
          </span>
        </div>
      </div>

      <h1 className="font-display -mt-1 text-6xl font-bold leading-[0.95] tracking-tight text-ink sm:text-7xl">
        {firstName}
      </h1>

      <p className="mt-6 max-w-2xl text-[15px] leading-relaxed text-ink-soft">
        {coachLine}
      </p>

      <div className="mt-8 flex flex-wrap items-center gap-5">
        <Link
          to="/practice/new"
          className="group inline-flex h-12 items-center gap-2 rounded-lg bg-lime px-6 text-sm font-bold text-on-lime shadow-[0_0_30px_var(--color-lime-shadow)] transition-all hover:bg-lime-dim hover:shadow-[0_0_42px_var(--color-lime-shadow)]"
        >
          Iniciar práctica
          <ArrowUpRight
            className="h-4 w-4 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
            strokeWidth={2.4}
          />
        </Link>

        <div className="flex items-center gap-2 text-sm text-ink-soft">
          <span className="text-base" aria-hidden>
            🔥
          </span>
          <span className="font-semibold text-ink">{streakDays}</span>
          {streakDays === 1 ? "día seguido" : "días seguidos"}
        </div>
      </div>

      <VoiceBand />
    </section>
  );
}

/** Full-width voice signature — the only "extra" element, integrated as a
 * band rather than a nested card. */
function VoiceBand() {
  const bars = Array.from({ length: 48 }, (_, i) => {
    const wave = Math.sin(i * 0.5) * 0.3 + Math.sin(i * 1.7) * 0.18;
    return Math.min(1, Math.max(0.16, 0.5 + wave));
  });
  return (
    <div className="mt-9 border-t border-line pt-6">
      <div className="flex h-16 items-end gap-[2px] sm:gap-1">
        {bars.map((peak, i) => (
          <span
            key={i}
            className="eq-bar flex-1 rounded-full bg-accent"
            style={{
              height: `${peak * 100}%`,
              animationDelay: `${(i % 9) * 0.1}s`,
              animationDuration: `${1 + (i % 4) * 0.22}s`,
            }}
          />
        ))}
      </div>
    </div>
  );
}
