import { Gauge, MessageSquare, Mic, Zap } from "lucide-react";

import { formatTime, paceLabel } from "@/lib/practice/fillers";
import { cn } from "@/lib/utils";

interface FloatingMetricsProps {
  elapsedSeconds: number;
  fillerTotal: number;
  wpm: number;
  isListening: boolean;
}

export function FloatingMetrics({
  elapsedSeconds,
  fillerTotal,
  wpm,
  isListening,
}: FloatingMetricsProps) {
  const pace = paceLabel(wpm);
  const wpmTone =
    wpm === 0 ? "default" : pace.tone === "ok" ? "ok" : pace.tone === "fast" ? "warn" : "warn";
  const fillerTone = fillerTotal === 0 ? "ok" : fillerTotal > 5 ? "warn" : "default";

  return (
    <aside className="w-full rounded-2xl border border-gray-200 bg-white p-4 lg:w-[230px]">
      <header className="mb-3 flex items-baseline justify-between border-b border-gray-100 pb-2.5">
        <h3 className="text-sm font-bold text-[#0A0A0A]">Métricas</h3>
        <span className="font-mono text-[11px] text-gray-400">{formatTime(elapsedSeconds)}</span>
      </header>
      <ul className="flex flex-col gap-3">
        <Row
          icon={<Zap className="h-3.5 w-3.5" strokeWidth={1.8} />}
          label="WPM"
          value={wpm > 0 ? Math.round(wpm).toString() : "—"}
          tone={wpmTone}
        />
        <Row
          icon={<MessageSquare className="h-3.5 w-3.5" strokeWidth={1.8} />}
          label="Muletillas"
          value={fillerTotal.toString()}
          tone={fillerTone}
        />
        <Row
          icon={<Gauge className="h-3.5 w-3.5" strokeWidth={1.8} />}
          label="Ritmo"
          value={wpm > 0 ? pace.label : "—"}
          tone={wpmTone}
        />
        <Row
          icon={<Mic className="h-3.5 w-3.5" strokeWidth={1.8} />}
          label="Micrófono"
          value={isListening ? "OK" : "Silencio"}
          tone={isListening ? "ok" : "default"}
        />
      </ul>
    </aside>
  );
}

function Row({
  icon,
  label,
  value,
  tone,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  tone: "default" | "ok" | "warn";
}) {
  return (
    <li className="flex items-center justify-between gap-3">
      <span className="flex items-center gap-2 text-xs text-gray-700">
        <span className="grid h-5 w-5 place-items-center rounded-md bg-gray-100 text-[#0A0A0A]">
          {icon}
        </span>
        {label}
      </span>
      <span
        className={cn(
          "font-mono text-sm font-bold",
          tone === "default" && "text-[#0A0A0A]",
          tone === "ok" && "text-emerald-600",
          tone === "warn" && "text-amber-600",
        )}
      >
        {value}
      </span>
    </li>
  );
}
