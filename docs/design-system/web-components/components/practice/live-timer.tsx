import { formatTime } from "@/lib/practice/fillers";

interface LiveTimerProps {
  elapsedSeconds: number;
}

export function LiveTimer({ elapsedSeconds }: LiveTimerProps) {
  return (
    <div className="inline-flex items-center gap-2.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5">
      <span className="h-2 w-2 rounded-full bg-red-500" />
      <span className="text-xs text-gray-500">Grabando</span>
      <span className="font-mono text-sm font-semibold text-[#0A0A0A]">
        {formatTime(elapsedSeconds)}
      </span>
    </div>
  );
}
