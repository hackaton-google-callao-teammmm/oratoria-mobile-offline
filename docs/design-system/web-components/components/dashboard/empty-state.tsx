import { Link } from "@tanstack/react-router";
import { ArrowUpRight, Mic } from "lucide-react";

interface EmptyStateProps {
  firstName: string;
}

export function EmptyState({ firstName }: EmptyStateProps) {
  return (
    <div className="flex flex-col gap-4">
      <section className="relative overflow-hidden rounded-2xl border border-line bg-surface p-10 text-center sm:p-14">
        <div
          aria-hidden
          className="pointer-events-none absolute left-1/2 top-0 h-72 w-72 -translate-x-1/2 rounded-full bg-lime/10 blur-3xl"
        />
        <span className="relative mx-auto grid h-14 w-14 place-items-center rounded-xl border border-line bg-stage text-accent">
          <Mic className="h-6 w-6" strokeWidth={1.8} />
        </span>
        <h1 className="font-display relative mt-6 text-3xl font-semibold tracking-tight text-ink">
          Listo para entrenar, {firstName}.
        </h1>
        <p className="relative mx-auto mt-3 max-w-md text-[15px] leading-relaxed text-ink-soft">
          Todavía no tienes sesiones. Habla unos minutos frente a una audiencia
          simulada y recibe tu primer reporte con score, una fortaleza y una
          mejora accionable.
        </p>
        <div className="relative mt-7 flex justify-center">
          <Link
            to="/practice/new"
            className="group inline-flex h-12 items-center gap-2 rounded-lg bg-lime px-6 text-sm font-bold text-on-lime shadow-[0_0_30px_var(--color-lime-shadow)] transition-all hover:bg-lime-dim"
          >
            Empezar mi primera práctica
            <ArrowUpRight
              className="h-4 w-4 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
              strokeWidth={2.4}
            />
          </Link>
        </div>
      </section>

      <section className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <Step
          n={1}
          title="Habla con naturalidad"
          body="Sobre lo que prefieras: un pitch, una clase, una entrevista."
        />
        <Step
          n={2}
          title="Feedback en vivo"
          body="Detectamos muletillas, ritmo y duración mientras hablas."
        />
        <Step
          n={3}
          title="Leé tu reporte"
          body="Score 0–100, una fortaleza y una mejora accionable."
        />
      </section>
    </div>
  );
}

function Step({ n, title, body }: { n: number; title: string; body: string }) {
  return (
    <article className="rounded-xl border border-line bg-surface p-5">
      <span className="grid h-7 w-7 place-items-center rounded-full border border-line bg-stage text-xs font-bold text-accent">
        {n}
      </span>
      <h3 className="mt-3 text-sm font-semibold text-ink">{title}</h3>
      <p className="mt-1 text-xs leading-relaxed text-ink-soft">{body}</p>
    </article>
  );
}
