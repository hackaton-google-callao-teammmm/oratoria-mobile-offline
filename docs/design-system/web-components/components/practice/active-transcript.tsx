import { Loader2 } from "lucide-react";
import { useEffect, useRef } from "react";

import { SPANISH_FILLERS } from "@/lib/practice/fillers";

interface ActiveTranscriptProps {
  transcript: string;
  isTranscribing: boolean;
  recording: boolean;
}

const FILLER_SET = new Set<string>(SPANISH_FILLERS as readonly string[]);
const FILLER_RE = new RegExp(
  `\\b(${SPANISH_FILLERS.map((f) => f.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|")})\\b`,
  "gi",
);

export function ActiveTranscript({
  transcript,
  isTranscribing,
  recording,
}: ActiveTranscriptProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = scrollRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [transcript]);

  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-faint">
          Transcripción en vivo
        </h3>
        {isTranscribing && (
          <span className="flex items-center gap-1.5 text-[11px] text-ink-faint">
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
            Transcribiendo
          </span>
        )}
      </div>
      <div
        ref={scrollRef}
        className="max-h-48 overflow-y-auto border-t border-line pt-4 text-[15px] leading-relaxed text-ink"
      >
        {transcript ? (
          <p className="whitespace-pre-wrap">
            {renderHighlighted(transcript)}
            {recording && (
              <span className="ml-0.5 inline-block h-[18px] w-0.5 animate-pulse bg-accent align-middle" />
            )}
          </p>
        ) : (
          <p className="text-ink-faint">
            {recording
              ? "Tus primeras palabras aparecerán en unos segundos…"
              : "Tocá el micrófono para empezar. Acá vas a ver lo que decís, con las muletillas resaltadas."}
          </p>
        )}
      </div>
    </div>
  );
}

function renderHighlighted(text: string): React.ReactNode[] {
  const out: React.ReactNode[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  FILLER_RE.lastIndex = 0;
  while ((match = FILLER_RE.exec(text)) !== null) {
    if (match.index > lastIndex) out.push(text.slice(lastIndex, match.index));
    const matched = match[0];
    const isFiller = FILLER_SET.has(matched.toLowerCase());
    out.push(
      <mark
        key={`${match.index}-${matched}`}
        className={
          isFiller
            ? "rounded bg-amber-400/25 px-1 font-semibold text-amber-700 dark:text-amber-300"
            : ""
        }
      >
        {matched}
      </mark>,
    );
    lastIndex = match.index + matched.length;
  }
  if (lastIndex < text.length) out.push(text.slice(lastIndex));
  return out;
}
