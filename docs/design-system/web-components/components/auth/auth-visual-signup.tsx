/** Right-hand visual panel for the SIGN-UP screen — Raycast-style backdrop. */
import { AuthBackdrop } from "./auth-backdrop";

export function AuthVisualSignup() {
  return (
    <aside className="relative hidden flex-col justify-center overflow-hidden p-12 lg:flex">
      <AuthBackdrop />
      {/* Legibility scrim: calms the centre band so text/cards read clearly
          while the neon keeps glowing at the edges. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(78%_64%_at_50%_50%,rgba(3,6,2,0.66),transparent_80%)]"
      />

      <div className="relative z-10 mx-auto flex w-full max-w-sm flex-col gap-8">
        <header className="text-center">
          <h2 className="text-balance text-[32px] font-bold leading-[1.12] tracking-tight text-white drop-shadow-[0_2px_12px_rgba(0,0,0,0.55)]">
            Empieza a <span className="text-[#C6FF3D]">hablar mejor</span> hoy
          </h2>
          <p className="mx-auto mt-3 max-w-xs text-[14px] leading-relaxed text-white/75">
            Crea tu cuenta y haz tu primera sesión en minutos. Sin tarjeta.
          </p>
        </header>
        <SignupMockup />
        <QuoteCard />
      </div>
    </aside>
  );
}

function SignupMockup() {
  return (
    <div className="auth-card p-6">
      <div
        className="mx-auto mb-4 grid h-16 w-16 place-items-center rounded-full bg-[#C6FF3D]"
        style={{
          boxShadow:
            "0 0 24px rgba(57,255,20,0.6), 0 0 0 8px rgba(198,255,61,0.12)",
        }}
      >
        <Equalizer />
      </div>
      <p className="text-center text-sm font-semibold text-white">
        Tu primera sesión
      </p>
      <p className="mt-0.5 text-center text-xs text-white/65">
        Así de simple, en 3 pasos
      </p>
      <ol className="relative mt-5 space-y-3.5">
        <span
          aria-hidden
          className="absolute bottom-3 left-3 top-3 w-px bg-gradient-to-b from-[#39FF14]/50 to-[#39FF14]/10"
        />
        {SESSION_STEPS.map((step, i) => (
          <li key={step} className="relative flex items-center gap-3">
            <span className="z-10 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-[#0e140a] text-[11px] font-bold text-[#39FF14] ring-1 ring-[#39FF14]/40">
              {i + 1}
            </span>
            <span className="text-[13px] leading-snug text-white/85">
              {step}
            </span>
          </li>
        ))}
      </ol>
    </div>
  );
}

const SESSION_STEPS = [
  "Grabas un pitch de 2 minutos",
  "La IA analiza tu voz y tu discurso",
  "Recibes tu score y tu próximo paso",
];

function Equalizer() {
  const heights = [14, 22, 30, 22, 14];
  return (
    <div className="flex items-center gap-[3px]">
      {heights.map((h, i) => (
        <span
          key={i}
          className="eq-bar w-1 rounded-sm bg-[#0A0A0A]"
          style={{ height: `${h}px`, animationDelay: `${i * 0.13}s` }}
        />
      ))}
    </div>
  );
}

function QuoteCard() {
  return (
    <figure className="relative pl-5">
      <span
        aria-hidden
        className="absolute bottom-1.5 left-0 top-1.5 w-[3px] rounded-full bg-gradient-to-b from-[#39FF14] to-[#39FF14]/0"
      />
      <p className="text-[15px] font-medium leading-relaxed text-white/90">
        Pasé de tartamudear en mis pitches a cerrar mi primera ronda de
        inversión.
      </p>
      <figcaption className="mt-3 flex items-center gap-2.5">
        <img
          src="/testimonial-maria.jpg"
          alt="María González"
          className="h-9 w-9 shrink-0 rounded-full object-cover ring-1 ring-white/15"
        />
        <div>
          <div className="text-[13px] font-bold text-white">María González</div>
          <div className="text-[11px] text-white/55">CEO · Fintech LATAM</div>
        </div>
      </figcaption>
    </figure>
  );
}
