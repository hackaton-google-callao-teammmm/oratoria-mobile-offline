import { useEffect, useState } from "react";

const STEPS = [
  "Procesando audio · transcripción completa",
  "Detectando muletillas y pausas",
  "Evaluando estructura, claridad y ritmo",
  "Generando recomendaciones personalizadas",
] as const;

const DID_YOU_KNOW = [
  {
    quote:
      "Los grandes oradores usan pausas de 2–3 segundos antes de los puntos clave: aumentan el impacto percibido en un 40%.",
    source: "— Comunicación efectiva, Carmine Gallo",
  },
  {
    quote:
      "Bajar 20 wpm tu ritmo cuando llegás al cierre dispara la retención en la audiencia hasta un 55%.",
    source: "— TED Speaker Coaching, 2022",
  },
  {
    quote:
      "Reemplazar una muletilla por un silencio de 1s te hace sonar 30% más seguro al oído humano.",
    source: "— Stanford GSB · Public Speaking Lab",
  },
];

/** Waveform bars using the .eq-bar CSS class from index.css */
function VoiceWaveform() {
  const bars = Array.from({ length: 32 }, (_, i) => {
    const wave = Math.sin(i * 0.55) * 0.35 + Math.sin(i * 1.9) * 0.2;
    return Math.min(1, Math.max(0.14, 0.48 + wave));
  });
  return (
    <div className="flex h-14 items-end gap-[3px]" aria-hidden>
      {bars.map((peak, i) => (
        <span
          key={i}
          className="eq-bar flex-1 rounded-full bg-accent"
          style={{
            height: `${peak * 100}%`,
            animationDelay: `${(i % 9) * 0.11}s`,
            animationDuration: `${1 + (i % 4) * 0.2}s`,
          }}
        />
      ))}
    </div>
  );
}

export function AnalyzingState() {
  const [active, setActive] = useState(0);
  const [tip] = useState(
    () => DID_YOU_KNOW[Math.floor(Math.random() * DID_YOU_KNOW.length)],
  );

  useEffect(() => {
    const id = window.setInterval(() => {
      setActive((s) => Math.min(s + 1, STEPS.length - 1));
    }, 1600);
    return () => window.clearInterval(id);
  }, []);

  return (
    <div className="mx-auto flex max-w-lg flex-col items-center gap-10 py-14 text-center">
      {/* Waveform focal element */}
      <div className="w-full px-4">
        <VoiceWaveform />
      </div>

      {/* Heading */}
      <div>
        <h1 className="font-display text-5xl font-bold tracking-tight text-ink sm:text-6xl">
          Analizando tu sesión…
        </h1>
        <p className="mt-3 text-[15px] text-ink-soft">
          Esto suele tomar 5–15 segundos.
        </p>
      </div>

      {/* Vertical timeline */}
      <div className="w-full text-left">
        <ol className="relative flex flex-col gap-0 pl-5">
          {/* vertical rail */}
          <span
            className="pointer-events-none absolute left-[7px] top-2 bottom-2 w-px bg-line"
            aria-hidden
          />
          {STEPS.map((step, i) => {
            const status =
              i < active ? "done" : i === active ? "active" : "pending";
            return (
              <li key={step} className="relative flex items-start gap-4 py-3">
                {/* state dot */}
                <span
                  className={[
                    "relative z-10 mt-0.5 h-3.5 w-3.5 shrink-0 rounded-full ring-2 ring-stage",
                    status === "done"
                      ? "bg-accent"
                      : status === "active"
                        ? "bg-accent animate-pulse"
                        : "bg-surface-2",
                  ].join(" ")}
                  aria-hidden
                />
                <span
                  className={
                    status === "active"
                      ? "text-[13px] font-semibold text-ink"
                      : status === "done"
                        ? "text-[13px] text-ink-soft"
                        : "text-[13px] text-ink-faint"
                  }
                >
                  {step}
                </span>
              </li>
            );
          })}
        </ol>
      </div>

      {/* Footnote tip */}
      <div className="w-full border-t border-line pt-6 text-left">
        <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-faint">
          ¿Sabías que…?
        </p>
        <p className="mt-2 text-[14px] leading-relaxed text-ink-soft">
          {tip.quote}
        </p>
        <p className="mt-1.5 text-xs text-ink-faint">{tip.source}</p>
      </div>
    </div>
  );
}
