import { ArrowRight, RotateCcw, ThumbsUp, Wrench } from "lucide-react";

import { SPANISH_FILLERS } from "@/lib/practice/fillers";

interface FinalReportProps {
  score: number;
  summary: string;
  strengthTitle: string;
  strengthText: string;
  improvementTitle: string;
  improvementText: string;
  metrics: {
    durationSeconds: number;
    fillerTotal: number;
    fillerByWord: Array<{ word: string; count: number }>;
    wpm: number;
    transcript: string;
  };
  onNewSession: () => void;
  onBackToDashboard: () => void;
}

export function FinalReport({
  score,
  summary,
  strengthTitle,
  strengthText,
  improvementTitle,
  improvementText,
  metrics,
  onNewSession,
  onBackToDashboard,
}: FinalReportProps) {
  const minutes = Math.floor(metrics.durationSeconds / 60);
  const seconds = Math.floor(metrics.durationSeconds % 60);
  const scoreTone =
    score >= 75 ? "text-emerald-500" : score >= 50 ? "text-amber-500" : "text-red-500";

  return (
    <div className="flex flex-col gap-5">
      <div className="grid grid-cols-1 items-center gap-6 rounded-2xl border border-gray-200 bg-white p-6 sm:grid-cols-[auto_1fr]">
        <div className="grid h-28 w-28 place-items-center rounded-full bg-gray-50">
          <div className="text-center">
            <div className={`text-5xl font-bold tracking-tight ${scoreTone}`}>
              {score}
            </div>
            <div className="mt-0.5 text-xs text-gray-500">/ 100</div>
          </div>
        </div>
        <div>
          <h3 className="text-xl font-bold tracking-tight text-[#0A0A0A]">
            Sesión analizada
          </h3>
          <p className="mt-1 text-sm leading-relaxed text-gray-700">{summary}</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <SmallMetric label="Duración" value={`${minutes}:${seconds.toString().padStart(2, "0")}`} />
        <SmallMetric label="Muletillas" value={metrics.fillerTotal.toString()} />
        <SmallMetric label="Palabras/min" value={Math.round(metrics.wpm).toString()} />
      </div>

      <FillersBreakdown
        total={metrics.fillerTotal}
        byWord={metrics.fillerByWord}
      />

      <TranscriptCard transcript={metrics.transcript} />

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Card
          icon={<ThumbsUp className="h-5 w-5" />}
          tone="lime"
          eyebrow="Fortaleza"
          title={strengthTitle}
          body={strengthText}
        />
        <Card
          icon={<Wrench className="h-5 w-5" />}
          tone="dark"
          eyebrow="A mejorar"
          title={improvementTitle}
          body={improvementText}
        />
      </div>

      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <button
          type="button"
          onClick={onBackToDashboard}
          className="inline-flex h-11 items-center justify-center rounded-lg border border-gray-200 bg-white px-5 text-sm font-semibold text-[#0A0A0A] transition-colors hover:border-gray-300"
        >
          Volver al dashboard
        </button>
        <button
          type="button"
          onClick={onNewSession}
          className="inline-flex h-11 items-center justify-center gap-2 rounded-lg bg-[#C6FF3D] px-5 text-sm font-bold text-[#0A0A0A] transition-all hover:-translate-y-0.5 hover:bg-[#D4FF7A]"
        >
          <RotateCcw className="h-4 w-4" strokeWidth={2.5} />
          Nueva sesión
          <ArrowRight className="h-4 w-4" strokeWidth={2.5} />
        </button>
      </div>
    </div>
  );
}

function FillersBreakdown({
  total,
  byWord,
}: {
  total: number;
  byWord: Array<{ word: string; count: number }>;
}) {
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5">
      <div className="mb-3 flex items-center justify-between">
        <h4 className="text-sm font-semibold text-[#0A0A0A]">Muletillas detectadas</h4>
        <span className="text-xs text-gray-500">{total} en total</span>
      </div>
      {byWord.length === 0 ? (
        <p className="text-sm text-gray-500">
          No detectamos ninguna muletilla en esta sesión.
        </p>
      ) : (
        <ul className="flex flex-wrap gap-2">
          {byWord.map(({ word, count }) => (
            <li
              key={word}
              className="inline-flex items-center gap-1.5 rounded-full bg-amber-50 px-3 py-1 text-xs text-amber-900"
            >
              <span className="font-semibold">“{word}”</span>
              <span className="text-amber-700">×{count}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

const FILLER_SET = new Set<string>(SPANISH_FILLERS as readonly string[]);
const FILLER_RE = new RegExp(
  `\\b(${SPANISH_FILLERS.map((f) => f.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|")})\\b`,
  "gi",
);

function TranscriptCard({ transcript }: { transcript: string }) {
  return (
    <div className="rounded-2xl border border-gray-200 bg-white">
      <div className="border-b border-gray-100 px-5 py-3">
        <h4 className="text-sm font-semibold text-[#0A0A0A]">Transcripción completa</h4>
      </div>
      <div className="max-h-72 overflow-y-auto px-5 py-4 text-sm leading-relaxed text-gray-800">
        <p className="whitespace-pre-wrap">{renderHighlighted(transcript)}</p>
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
            ? "rounded bg-amber-200/70 px-1 py-0 font-semibold text-amber-900"
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

function SmallMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-3.5">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-bold tracking-tight text-[#0A0A0A]">{value}</div>
    </div>
  );
}

function Card({
  icon,
  tone,
  eyebrow,
  title,
  body,
}: {
  icon: React.ReactNode;
  tone: "lime" | "dark";
  eyebrow: string;
  title: string;
  body: string;
}) {
  if (tone === "dark") {
    return (
      <div className="flex items-start gap-3 rounded-2xl border border-[#0A0A0A] bg-[#0A0A0A] p-5 text-white">
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-[#C6FF3D] text-[#0A0A0A]">
          {icon}
        </span>
        <div>
          <p className="text-xs font-semibold text-[#C6FF3D]">{eyebrow}</p>
          <h4 className="mt-0.5 text-base font-bold">{title}</h4>
          <p className="mt-1 text-sm leading-relaxed text-gray-300">{body}</p>
        </div>
      </div>
    );
  }
  return (
    <div className="flex items-start gap-3 rounded-2xl border border-gray-200 bg-white p-5">
      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-[#F7FFE0] text-[#0A0A0A]">
        {icon}
      </span>
      <div>
        <p className="text-xs font-semibold text-emerald-700">{eyebrow}</p>
        <h4 className="mt-0.5 text-base font-bold text-[#0A0A0A]">{title}</h4>
        <p className="mt-1 text-sm leading-relaxed text-gray-700">{body}</p>
      </div>
    </div>
  );
}
