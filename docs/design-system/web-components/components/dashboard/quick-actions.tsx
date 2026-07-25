import { Link } from "@tanstack/react-router";
import { ArrowRight } from "lucide-react";

export function QuickActions() {
  return (
    <div className="flex flex-col gap-3">
      <ActionRow
        title="Práctica libre"
        description="Habla sin guion y recibe tu reporte."
        href="/practice/new"
      />
      <ActionRow
        title="Subir un video"
        description="Análisis asíncrono de una grabación."
        disabled
      />
    </div>
  );
}

interface ActionRowProps {
  title: string;
  description: string;
  href?: string;
  disabled?: boolean;
}

function ActionRow({
  title,
  description,
  href,
  disabled = false,
}: ActionRowProps) {
  const body = (
    <div
      className={`group flex items-center justify-between gap-4 rounded-xl bg-surface p-4 transition-colors ${
        disabled ? "opacity-60" : "hover:bg-surface-2"
      }`}
    >
      <div className="min-w-0">
        <h3 className="text-[15px] font-semibold tracking-tight text-ink">
          {title}
        </h3>
        <p className="mt-0.5 truncate text-[13px] text-ink-soft">
          {description}
        </p>
      </div>
      {disabled ? (
        <span className="shrink-0 rounded-full bg-surface-2 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider text-ink-faint">
          Pronto
        </span>
      ) : (
        <ArrowRight
          className="h-4 w-4 shrink-0 text-accent transition-transform group-hover:translate-x-0.5"
          strokeWidth={2.4}
        />
      )}
    </div>
  );

  if (href && !disabled) {
    return <Link to={href}>{body}</Link>;
  }
  return body;
}
