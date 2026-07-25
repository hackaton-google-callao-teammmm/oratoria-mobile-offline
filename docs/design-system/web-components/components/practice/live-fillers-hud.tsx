/**
 * LiveFillersHud — translucent paraverbal overlay shown on top of the avatar
 * video during an Audiencia Digital session. Mirrors the simple-practice live
 * feedback (fillers / pace / elapsed) but styled to sit over dark video, and
 * adds a "muted while the avatar speaks" indicator driven by the echo gate.
 *
 * Counts are computed by the caller from the STABLE Deepgram transcript only
 * (never interim) so the numbers never flicker. See use-deepgram.ts.
 */

interface LiveFillersHudProps {
  fillers: number;
  wpm: number;
  paceLabel: string;
  /** When true, paint pace in the warning tone (too fast). */
  paceWarn?: boolean;
  elapsedSeconds: number;
  /** Deepgram WebSocket connected and receiving audio. */
  connected: boolean;
  /** Echo gate active — mic muted because the avatar is speaking. */
  gated: boolean;
  /** Whether the speaker has produced any speech yet. */
  hasSpoken: boolean;
  /** Latest live line (stable transcript + interim) for a one-line preview. */
  liveLine?: string;
}

function fmtElapsed(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  const mm = String(Math.floor(s / 60)).padStart(2, "0");
  const ss = String(s % 60).padStart(2, "0");
  return `${mm}:${ss}`;
}

function Stat({
  label,
  value,
  warn,
}: {
  label: string;
  value: string;
  warn?: boolean;
}) {
  return (
    <div className="flex flex-col">
      <span className="text-[10px] font-medium uppercase tracking-wider text-white/55">
        {label}
      </span>
      <span
        className={`text-xl font-bold tabular-nums leading-tight ${
          warn ? "text-amber-400" : "text-[#C6FF3D]"
        }`}
      >
        {value}
      </span>
    </div>
  );
}

export function LiveFillersHud({
  fillers,
  wpm,
  paceLabel,
  paceWarn,
  elapsedSeconds,
  connected,
  gated,
  hasSpoken,
  liveLine,
}: LiveFillersHudProps) {
  return (
    <div className="pointer-events-none absolute left-4 top-4 z-10 w-64 max-w-[80vw]">
      <div className="rounded-xl border border-white/10 bg-black/60 p-3.5 shadow-lg backdrop-blur-md">
        <div className="mb-2.5 flex items-center justify-between">
          <span className="text-[11px] font-semibold uppercase tracking-wider text-white/70">
            En vivo
          </span>
          <span className="flex items-center gap-1.5 text-[10px] text-white/55">
            <span
              className={`h-1.5 w-1.5 rounded-full ${
                connected ? "bg-[#C6FF3D]" : "bg-white/30"
              }`}
            />
            {connected ? "Deepgram" : "conectando…"}
          </span>
        </div>

        <div className="grid grid-cols-3 gap-2">
          <Stat
            label="Muletillas"
            value={hasSpoken ? String(fillers) : "—"}
            warn={fillers > 5}
          />
          <Stat
            label="Pal/min"
            value={hasSpoken && wpm > 0 ? String(Math.round(wpm)) : "—"}
            warn={paceWarn}
          />
          <Stat label="Tiempo" value={fmtElapsed(elapsedSeconds)} />
        </div>

        {hasSpoken && wpm > 0 && (
          <div className="mt-1.5 text-[10px] text-white/45">
            Ritmo: <span className="text-white/70">{paceLabel}</span>
          </div>
        )}

        {gated && (
          <div className="mt-2.5 flex items-center gap-1.5 rounded-md bg-white/10 px-2 py-1 text-[10px] font-medium text-white/70">
            <span className="h-1.5 w-1.5 rounded-full bg-amber-400" />
            Mic en pausa — la audiencia está hablando
          </div>
        )}

        {liveLine ? (
          <p className="mt-2.5 line-clamp-2 text-[11px] leading-snug text-white/60">
            {liveLine}
          </p>
        ) : null}
      </div>
    </div>
  );
}
