import { Lightbulb } from "lucide-react";

import { recommendation } from "@/lib/dashboard/mock-data";

export function RecommendationBanner() {
  return (
    <div className="grid grid-cols-1 items-center gap-5 rounded-2xl bg-[#0A0A0A] p-6 text-white sm:grid-cols-[auto_1fr_auto]">
      <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-[#C6FF3D] text-[#0A0A0A]">
        <Lightbulb className="h-5 w-5" strokeWidth={2} />
      </span>

      <div>
        <h3 className="text-base font-bold">{recommendation.title}</h3>
        <p className="mt-1 max-w-md text-[13px] leading-relaxed text-gray-400">
          {recommendation.body}
        </p>
      </div>

      <button
        type="button"
        className="inline-flex h-11 shrink-0 items-center rounded-lg bg-[#C6FF3D] px-5 text-[13px] font-bold text-[#0A0A0A] transition-colors hover:bg-[#D4FF7A]"
      >
        Configurar sesión
      </button>
    </div>
  );
}
