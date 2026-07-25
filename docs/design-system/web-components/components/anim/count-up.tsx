/**
 * Number that counts up to its target with GSAP — a small, satisfying
 * touch on the dashboard figures. Skips the tween under reduced-motion
 * and re-runs whenever `value` changes.
 */
import gsap from "gsap";
import { useEffect, useRef } from "react";

interface CountUpProps {
  value: number;
  duration?: number;
  className?: string;
}

export function CountUp({ value, duration = 1.1, className }: CountUpProps) {
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    if (
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      el.textContent = String(value);
      return;
    }

    const counter = { n: 0 };
    const tween = gsap.to(counter, {
      n: value,
      duration,
      ease: "power2.out",
      onUpdate: () => {
        el.textContent = String(Math.round(counter.n));
      },
    });

    return () => {
      tween.kill();
    };
  }, [value, duration]);

  return (
    <span ref={ref} className={className}>
      {value}
    </span>
  );
}
