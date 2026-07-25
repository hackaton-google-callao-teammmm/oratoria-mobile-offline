/**
 * Radial recorder — the live-session focal point.
 *
 * A circular, audio-reactive visualizer: lime bars radiate from the
 * centre in response to the microphone's frequency spectrum, wrapped by
 * an SVG ring that tracks progress toward the target duration. The mic
 * start/stop button sits at the core. Idle, the bars breathe gently.
 *
 * Colours resolve from theme tokens (light/dark). Honors reduced motion.
 */
import { Mic, Square } from "lucide-react";
import { useEffect, useRef } from "react";

import type { RecorderState } from "@/components/audio/recorder";
import { cn } from "@/lib/utils";

function themeColor(name: string, fallback: string): string {
  if (typeof document === "undefined") return fallback;
  return (
    getComputedStyle(document.documentElement).getPropertyValue(name).trim() ||
    fallback
  );
}

const SIZE = 340;
const BARS = 72;
const INNER = SIZE * 0.3;
const MAX_LEN = SIZE * 0.15;
const RING_R = SIZE / 2 - 6;
const RING_C = 2 * Math.PI * RING_R;

interface RadialRecorderProps {
  stream?: MediaStream | null;
  state: RecorderState;
  duration: number;
  targetMinutes: number;
  onStart: () => void | Promise<void>;
  onStop: () => void | Promise<void>;
  disabled?: boolean;
}

export function RadialRecorder({
  stream,
  state,
  duration,
  targetMinutes,
  onStart,
  onStop,
  disabled,
}: RadialRecorderProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const recording = state === "recording";
  const starting = state === "starting";
  const stopping = state === "stopping";

  const target = Math.max(1, targetMinutes * 60);
  const progress = Math.min(1, duration / target);

  // Live spectrum (when streaming) or a gentle idle breathing.
  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const cx = SIZE / 2;
    const cy = SIZE / 2;
    let raf = 0;
    let cleanupAudio: (() => void) | null = null;
    let analyser: AnalyserNode | null = null;
    let data: Uint8Array | null = null;

    if (stream) {
      const AudioCtor: typeof AudioContext =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext })
          .webkitAudioContext;
      const audioCtx = new AudioCtor();
      const source = audioCtx.createMediaStreamSource(stream);
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.8;
      source.connect(analyser);
      data = new Uint8Array(analyser.frequencyBinCount);
      cleanupAudio = () => {
        source.disconnect();
        analyser?.disconnect();
        void audioCtx.close();
      };
    }

    const drawBar = (ang: number, len: number, accent: string) => {
      const x1 = cx + Math.cos(ang) * INNER;
      const y1 = cy + Math.sin(ang) * INNER;
      const x2 = cx + Math.cos(ang) * (INNER + len);
      const y2 = cy + Math.sin(ang) * (INNER + len);
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.strokeStyle = accent;
      ctx.lineWidth = 3;
      ctx.lineCap = "round";
      ctx.stroke();
    };

    const render = (t: number) => {
      ctx.clearRect(0, 0, SIZE, SIZE);
      const accent = themeColor("--c-accent", "#C6FF3D");
      const half = BARS / 2;

      if (analyser && data) {
        analyser.getByteFrequencyData(data);
        const usable = Math.floor(data.length * 0.62);
        for (let i = 0; i < BARS; i++) {
          const mirrored = i < half ? i : BARS - i;
          const bin = Math.floor((mirrored / half) * usable);
          const v = data[bin] / 255;
          const len = Math.max(2, v * v * MAX_LEN * 1.6);
          drawBar((i / BARS) * Math.PI * 2 - Math.PI / 2, len, accent);
        }
      } else {
        // Idle breathing
        const base = reduce ? 0.35 : 0.3;
        for (let i = 0; i < BARS; i++) {
          const wave = reduce ? 0 : Math.sin(t / 600 + i * 0.4) * 0.18;
          const len = (base + wave) * (MAX_LEN * 0.5);
          drawBar((i / BARS) * Math.PI * 2 - Math.PI / 2, len, accent);
        }
      }
      raf = requestAnimationFrame(render);
    };
    raf = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(raf);
      cleanupAudio?.();
    };
  }, [stream]);

  return (
    <div
      className="relative grid place-items-center"
      style={{ width: SIZE, height: SIZE }}
    >
      {/* Glow */}
      <div
        aria-hidden
        className={cn(
          "pointer-events-none absolute inset-6 rounded-full blur-2xl transition-opacity duration-500",
          recording ? "bg-lime/20 opacity-100" : "bg-lime/10 opacity-60",
        )}
      />

      {/* Progress ring */}
      <svg
        viewBox={`0 0 ${SIZE} ${SIZE}`}
        className="absolute inset-0 h-full w-full -rotate-90"
        aria-hidden
      >
        <circle
          cx={SIZE / 2}
          cy={SIZE / 2}
          r={RING_R}
          fill="none"
          stroke="var(--color-line)"
          strokeWidth={3}
        />
        <circle
          cx={SIZE / 2}
          cy={SIZE / 2}
          r={RING_R}
          fill="none"
          stroke="var(--color-accent)"
          strokeWidth={3}
          strokeLinecap="round"
          strokeDasharray={RING_C}
          strokeDashoffset={RING_C * (1 - progress)}
          style={{ transition: "stroke-dashoffset 0.6s linear" }}
        />
      </svg>

      {/* Radial spectrum */}
      <canvas
        ref={canvasRef}
        width={SIZE}
        height={SIZE}
        className="absolute inset-0 h-full w-full"
      />

      {/* Center mic button */}
      <div className="relative grid place-items-center">
        {recording && (
          <>
            <span className="absolute h-24 w-24 animate-ping rounded-full bg-lime/25 [animation-duration:1.8s]" />
            <span className="absolute h-24 w-24 animate-ping rounded-full bg-lime/15 [animation-delay:0.6s] [animation-duration:1.8s]" />
          </>
        )}
        <button
          type="button"
          onClick={recording ? onStop : onStart}
          disabled={disabled || starting || stopping}
          aria-label={recording ? "Detener grabación" : "Empezar grabación"}
          className={cn(
            "relative grid h-24 w-24 place-items-center rounded-full transition-all hover:scale-105 disabled:cursor-not-allowed disabled:opacity-70",
            recording
              ? "bg-lime text-on-lime shadow-[0_0_48px_var(--color-lime-shadow)]"
              : "bg-ink text-stage shadow-xl shadow-black/25",
          )}
        >
          {recording ? (
            <Square className="h-8 w-8" fill="currentColor" />
          ) : (
            <Mic className="h-9 w-9" strokeWidth={1.8} />
          )}
        </button>
      </div>
    </div>
  );
}
