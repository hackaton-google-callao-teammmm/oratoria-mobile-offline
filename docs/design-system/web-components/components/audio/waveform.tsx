/**
 * Waveform visualizer.
 *
 * - Live: a MediaStream → real-time frequency spectrum drawn as mirrored
 *   lime bars on canvas (Web Audio AnalyserNode).
 * - Playback: an audioBlob → wavesurfer.js renders the full waveform.
 * - Idle: a calm, faint equalizer hint.
 *
 * Colors resolve from the active theme tokens so it adapts to light/dark.
 */
import { useEffect, useRef } from "react";
import WaveSurfer from "wavesurfer.js";

interface WaveformProps {
  stream?: MediaStream | null;
  audioBlob?: Blob | null;
  height?: number;
}

function themeColor(name: string, fallback: string): string {
  if (typeof document === "undefined") return fallback;
  const v = getComputedStyle(document.documentElement)
    .getPropertyValue(name)
    .trim();
  return v || fallback;
}

export function Waveform({ stream, audioBlob, height = 96 }: WaveformProps) {
  const liveCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const playbackContainerRef = useRef<HTMLDivElement | null>(null);
  const wavesurferRef = useRef<WaveSurfer | null>(null);

  // Live mode: mirrored frequency bars.
  useEffect(() => {
    if (!stream || !liveCanvasRef.current) return;

    const canvas = liveCanvasRef.current;
    const ctx2d = canvas.getContext("2d");
    if (!ctx2d) return;

    const AudioCtor: typeof AudioContext =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext: typeof AudioContext })
        .webkitAudioContext;
    const audioCtx = new AudioCtor();
    const source = audioCtx.createMediaStreamSource(stream);
    const analyser = audioCtx.createAnalyser();
    analyser.fftSize = 512;
    analyser.smoothingTimeConstant = 0.78;
    source.connect(analyser);

    const bins = analyser.frequencyBinCount;
    const data = new Uint8Array(bins);
    let raf = 0;

    const draw = () => {
      analyser.getByteFrequencyData(data);
      const { width, height: h } = canvas;
      ctx2d.clearRect(0, 0, width, h);
      const accent = themeColor("--c-accent", "#C6FF3D");

      const barCount = 56;
      const usable = Math.floor(bins * 0.66);
      const gap = 3;
      const barW = Math.max(2, (width - gap * (barCount - 1)) / barCount);
      ctx2d.fillStyle = accent;

      for (let i = 0; i < barCount; i++) {
        const idx = Math.floor((i / barCount) * usable);
        const v = data[idx] / 255;
        const barH = Math.max(barW, v * v * h * 0.95);
        const x = i * (barW + gap);
        const y = (h - barH) / 2;
        ctx2d.beginPath();
        if (ctx2d.roundRect) {
          ctx2d.roundRect(x, y, barW, barH, barW / 2);
        } else {
          ctx2d.rect(x, y, barW, barH);
        }
        ctx2d.fill();
      }
      raf = requestAnimationFrame(draw);
    };
    draw();

    return () => {
      cancelAnimationFrame(raf);
      source.disconnect();
      analyser.disconnect();
      void audioCtx.close();
    };
  }, [stream]);

  // Playback mode.
  useEffect(() => {
    if (!audioBlob || !playbackContainerRef.current) return;

    const ws = WaveSurfer.create({
      container: playbackContainerRef.current,
      waveColor: themeColor("--c-ink-faint", "#6d6d65"),
      progressColor: themeColor("--c-accent", "#C6FF3D"),
      cursorColor: themeColor("--c-ink-soft", "#a4a39a"),
      height,
      barWidth: 3,
      barRadius: 3,
      barGap: 2,
      normalize: true,
    });
    wavesurferRef.current = ws;

    const url = URL.createObjectURL(audioBlob);
    void ws.load(url);

    return () => {
      ws.destroy();
      wavesurferRef.current = null;
      URL.revokeObjectURL(url);
    };
  }, [audioBlob, height]);

  if (stream) {
    return (
      <canvas
        ref={liveCanvasRef}
        width={800}
        height={height}
        className="w-full rounded-xl bg-stage/40 ring-1 ring-line"
        style={{ height }}
      />
    );
  }
  if (audioBlob) {
    return (
      <div
        ref={playbackContainerRef}
        className="w-full rounded-xl bg-stage/40 px-3 ring-1 ring-line"
      />
    );
  }
  return (
    <div
      className="grid w-full place-items-center rounded-xl bg-stage/40 ring-1 ring-line"
      style={{ height }}
    >
      <div className="flex items-end gap-1.5 opacity-40">
        {[10, 20, 13, 26, 16, 22, 11, 18, 9].map((b, i) => (
          <span
            key={i}
            className="w-1.5 rounded-full bg-accent"
            style={{ height: `${b}px` }}
          />
        ))}
      </div>
    </div>
  );
}
