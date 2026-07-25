import { CheckSquare, MessageSquare } from "lucide-react";

import { activeRoutes, type ActiveRoute } from "@/lib/dashboard/mock-data";
import { cn } from "@/lib/utils";

export function RoutesGrid() {
  return (
    <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
      {activeRoutes.map((r) => (
        <RouteCard key={r.id} route={r} />
      ))}
    </div>
  );
}

function RouteCard({ route }: { route: ActiveRoute }) {
  const percent = Math.round((route.done / route.total) * 100);
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-4 transition-all hover:-translate-y-0.5 hover:shadow-sm">
      <div className="mb-3 flex items-center gap-3">
        <span
          className={cn(
            "grid h-9 w-9 shrink-0 place-items-center rounded-[10px]",
            route.variant === "lime" && "bg-[#C6FF3D] text-[#0A0A0A]",
            route.variant === "dark" && "bg-[#0A0A0A] text-[#C6FF3D]",
          )}
        >
          {route.variant === "lime" ? (
            <CheckSquare className="h-4 w-4" strokeWidth={1.8} />
          ) : (
            <MessageSquare className="h-4 w-4" strokeWidth={1.8} />
          )}
        </span>
        <div>
          <p className="text-sm font-bold tracking-tight text-[#0A0A0A]">{route.name}</p>
          <p className="mt-0.5 text-[11px] text-gray-500">
            Nivel {route.level} de {route.totalLevels} · {route.done} de {route.total} sesiones
          </p>
        </div>
      </div>
      <div className="mb-2.5 h-1.5 overflow-hidden rounded-sm bg-gray-100">
        <div className="h-full rounded-sm bg-[#C6FF3D]" style={{ width: `${percent}%` }} />
      </div>
      <div className="flex items-center justify-between text-xs text-gray-600">
        <span className="font-bold text-[#0A0A0A]">{percent}% completado</span>
        <button type="button" className="font-bold text-[#0A0A0A] hover:underline">
          Continuar ruta →
        </button>
      </div>
    </div>
  );
}
