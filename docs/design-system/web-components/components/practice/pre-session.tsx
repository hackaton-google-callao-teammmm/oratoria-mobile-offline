import { ArrowRight, Mic } from "lucide-react";

interface PreSessionProps {
  onStart: () => void;
  starting: boolean;
}

export function PreSession({ onStart, starting }: PreSessionProps) {
  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-8">
      <header className="text-center">
        <h1 className="text-3xl font-bold leading-tight tracking-tight text-[#0A0A0A]">
          ¿Listo para empezar?
        </h1>
        <p className="mt-2 text-[15px] text-gray-600">
          Habla con naturalidad sobre lo que prefieras. Detectamos muletillas, ritmo y
          duración mientras hablas; al detener te damos un reporte breve.
        </p>
      </header>

      <div className="rounded-2xl border border-gray-200 bg-white p-5">
        <div className="flex items-start gap-4">
          <span className="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-[#F7FFE0] text-[#0A0A0A]">
            <Mic className="h-5 w-5" strokeWidth={1.8} />
          </span>
          <div>
            <h2 className="text-sm font-bold text-[#0A0A0A]">Antes de empezar</h2>
            <ul className="mt-2 flex flex-col gap-1.5 text-[13px] leading-relaxed text-gray-700">
              <li>· Concédele al navegador permiso al micrófono cuando lo pida.</li>
              <li>· La transcripción se actualiza cada ocho segundos aproximadamente.</li>
              <li>· Habla como si fuera real, no leas un guión.</li>
              <li>· Puedes cancelar en cualquier momento sin guardar nada.</li>
            </ul>
          </div>
        </div>
      </div>

      <div className="flex justify-center">
        <button
          type="button"
          onClick={onStart}
          disabled={starting}
          className="inline-flex h-12 items-center gap-2 rounded-lg bg-[#C6FF3D] px-6 text-sm font-bold text-[#0A0A0A] shadow-sm transition-all hover:-translate-y-0.5 hover:bg-[#D4FF7A] disabled:cursor-not-allowed disabled:opacity-70"
        >
          {starting ? "Solicitando micrófono…" : "Empezar"}
          <ArrowRight className="h-4 w-4" strokeWidth={2.5} />
        </button>
      </div>
    </div>
  );
}
