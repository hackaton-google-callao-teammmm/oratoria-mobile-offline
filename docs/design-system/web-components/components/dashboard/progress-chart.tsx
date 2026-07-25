import { progressSeries } from "@/lib/dashboard/mock-data";

export function ProgressChart() {
  const linePath = progressSeries.points
    .map((p, i) => `${i === 0 ? "M" : "L"} ${p.x},${p.y}`)
    .join(" ");
  const areaPath = `${linePath} L 600,140 L 0,140 Z`;
  const last = progressSeries.points[progressSeries.points.length - 1];

  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5">
      <div className="grid grid-cols-1 items-center gap-6 lg:grid-cols-[1fr_220px]">
        <div>
          <svg viewBox="0 0 600 140" preserveAspectRatio="none" className="h-35 w-full">
            <defs>
              <linearGradient id="oratoria-progress-grad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#C6FF3D" stopOpacity="0.5" />
                <stop offset="100%" stopColor="#C6FF3D" stopOpacity="0" />
              </linearGradient>
            </defs>
            <line x1="0" y1="35" x2="600" y2="35" stroke="#F3F4F6" strokeWidth="1" />
            <line x1="0" y1="70" x2="600" y2="70" stroke="#F3F4F6" strokeWidth="1" />
            <line x1="0" y1="105" x2="600" y2="105" stroke="#F3F4F6" strokeWidth="1" />
            <path d={areaPath} fill="url(#oratoria-progress-grad)" />
            <path
              d={linePath}
              fill="none"
              stroke="#C6FF3D"
              strokeWidth="3"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            {progressSeries.highlightedIndices.map((i) => {
              const p = progressSeries.points[i];
              const isLast = i === progressSeries.points.length - 2;
              return (
                <circle
                  key={i}
                  cx={p.x}
                  cy={p.y}
                  r={isLast ? 6 : 4}
                  fill="#0A0A0A"
                  stroke={isLast ? "#C6FF3D" : undefined}
                  strokeWidth={isLast ? 3 : 0}
                />
              );
            })}
            <circle cx={last.x} cy={last.y} r={6} fill="#0A0A0A" stroke="#C6FF3D" strokeWidth={3} />
          </svg>
          <div className="mt-2 flex justify-between px-1 text-[11px] text-gray-500">
            {progressSeries.weekLabels.map((l) => (
              <span key={l}>{l}</span>
            ))}
          </div>
        </div>

        <div className="flex flex-col gap-3">
          <ChartStat label="Score actual" value={progressSeries.currentScore.toString()} />
          <ChartStat
            label="Mejora total"
            value={`+${progressSeries.improvement} pts`}
            valueClassName="text-emerald-500"
          />
          <ChartStat
            label="Mejor categoría"
            value={progressSeries.bestCategory}
            valueClassName="text-sm"
          />
        </div>
      </div>
    </div>
  );
}

function ChartStat({
  label,
  value,
  valueClassName = "",
}: {
  label: string;
  value: string;
  valueClassName?: string;
}) {
  return (
    <div className="flex items-baseline justify-between gap-2 border-b border-dashed border-gray-200 pb-3 last:border-b-0 last:pb-0">
      <span className="text-xs font-medium text-gray-500">{label}</span>
      <span className={`text-lg font-bold tracking-tight text-[#0A0A0A] ${valueClassName}`}>
        {value}
      </span>
    </div>
  );
}
