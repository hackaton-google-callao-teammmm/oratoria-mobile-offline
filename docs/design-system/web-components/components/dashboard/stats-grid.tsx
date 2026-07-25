import { CountUp } from "@/components/anim/count-up";

interface StatsGridProps {
  totalSessions: number;
  averageScore: number | null;
  weeklyCount: number;
  weeklyGoal: number;
  practicedSeconds: number;
}

export function StatsGrid({
  totalSessions,
  averageScore,
  weeklyCount,
  weeklyGoal,
  practicedSeconds,
}: StatsGridProps) {
  const hours = Math.floor(practicedSeconds / 3600);
  const minutes = Math.round((practicedSeconds % 3600) / 60);

  return (
    <div className="grid grid-cols-2 overflow-hidden rounded-2xl bg-surface sm:grid-cols-4 sm:divide-x sm:divide-line">
      <StatCard
        label="Score promedio"
        value={
          averageScore === null ? (
            "—"
          ) : (
            <>
              <CountUp value={averageScore} />
              <span className="ml-1 text-sm font-medium text-ink-faint">
                /100
              </span>
            </>
          )
        }
        meta={
          averageScore === null
            ? "Aún sin reportes"
            : averageScore >= 85
              ? "Nivel alto — sostené el listón"
              : "Margen para subir"
        }
      />

      <StatCard
        label="Esta semana"
        value={
          <>
            <CountUp value={weeklyCount} />
            <span className="ml-1 text-sm font-medium text-ink-faint">
              / {weeklyGoal}
            </span>
          </>
        }
        meta={
          <MetaProgress
            percent={weeklyGoal > 0 ? (weeklyCount / weeklyGoal) * 100 : 0}
          />
        }
      />

      <StatCard
        label="Tiempo practicado"
        value={
          hours > 0 ? (
            <>
              <CountUp value={hours} />
              <span className="text-sm font-medium text-ink-faint">h</span>{" "}
              <CountUp value={minutes} />
              <span className="text-sm font-medium text-ink-faint">m</span>
            </>
          ) : minutes > 0 ? (
            <>
              <CountUp value={minutes} />
              <span className="text-sm font-medium text-ink-faint">min</span>
            </>
          ) : (
            "—"
          )
        }
        meta="Frente al micrófono"
      />

      <StatCard
        label="Total de sesiones"
        value={<CountUp value={totalSessions} />}
        meta={
          totalSessions === 0 ? "Empieza la primera" : "Tu historial completo"
        }
      />
    </div>
  );
}

function StatCard({
  label,
  value,
  meta,
}: {
  label: string;
  value: React.ReactNode;
  meta: React.ReactNode;
}) {
  return (
    <div className="p-5 lg:p-6">
      <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-faint">
        {label}
      </span>
      <div className="font-display mt-3 flex items-baseline text-4xl font-bold tracking-tight tabular-nums text-ink">
        {value}
      </div>
      <div className="mt-3 flex items-center gap-1.5 text-xs text-ink-soft">
        {meta}
      </div>
    </div>
  );
}

function MetaProgress({ percent }: { percent: number }) {
  return (
    <div className="h-1 flex-1 overflow-hidden rounded-full bg-surface-2">
      <div
        className="h-full rounded-full bg-accent"
        style={{ width: `${Math.min(100, Math.max(0, percent))}%` }}
      />
    </div>
  );
}
