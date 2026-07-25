import { Mic, MicOff, Square, X } from "lucide-react";

interface ControlBarProps {
  micMuted: boolean;
  onToggleMic: () => void;
  onStop: () => void;
  onCancel: () => void;
}

export function ControlBar({ micMuted, onToggleMic, onStop, onCancel }: ControlBarProps) {
  return (
    <div className="flex items-center justify-center gap-5 pt-2">
      <CircleButton
        label="Mic"
        tone="default"
        onClick={onToggleMic}
        icon={
          micMuted ? (
            <MicOff className="h-5 w-5" strokeWidth={1.8} />
          ) : (
            <Mic className="h-5 w-5" strokeWidth={1.8} />
          )
        }
      />
      <CircleButton
        label="Detener"
        tone="primary"
        size="lg"
        onClick={onStop}
        icon={<Square className="h-7 w-7" strokeWidth={2.5} fill="currentColor" />}
      />
      <CircleButton
        label="Cancelar"
        tone="danger"
        onClick={onCancel}
        icon={<X className="h-5 w-5" strokeWidth={2} />}
      />
    </div>
  );
}

interface CircleButtonProps {
  icon: React.ReactNode;
  label: string;
  tone: "default" | "primary" | "danger";
  size?: "md" | "lg";
  onClick: () => void;
}

function CircleButton({ icon, label, tone, size = "md", onClick }: CircleButtonProps) {
  const dim = size === "lg" ? "h-[72px] w-[72px]" : "h-14 w-14";
  return (
    <div className="relative flex flex-col items-center">
      <button
        type="button"
        onClick={onClick}
        className={`grid ${dim} place-items-center rounded-full border transition-all hover:-translate-y-0.5 ${
          tone === "primary"
            ? "border-[#C6FF3D] bg-[#C6FF3D] text-[#0A0A0A] shadow-[0_8px_32px_-4px_rgba(198,255,61,0.55)] hover:bg-[#D4FF7A] hover:shadow-[0_12px_40px_-4px_rgba(198,255,61,0.7)]"
            : tone === "danger"
              ? "border-red-200 bg-red-50 text-red-600 hover:bg-red-100"
              : "border-gray-200 bg-white text-gray-700 hover:bg-gray-50 hover:text-[#0A0A0A]"
        }`}
      >
        {icon}
      </button>
      <span
        className={`mt-2 text-[10px] font-bold uppercase tracking-wider ${
          tone === "primary" ? "text-[#0A0A0A]" : "text-gray-500"
        }`}
      >
        {label}
      </span>
    </div>
  );
}
