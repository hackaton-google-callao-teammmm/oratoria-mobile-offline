# OratorIA — Design System (web ↔ mobile)

The **web frontend** (`oratorIA-frontend/apps/web`) and this **mobile app** share
one design system: _"High-performance arena"_ (web) / _"Spotlight"_ (mobile).
Electric **lime `#C6FF3D`** + near-black, dual light/dark, editorial cream, Inter

- JetBrains Mono, aurora mesh, glass cards, an equalizer voice motif.

**Source of truth:** the web CSS, copied here verbatim as
[`web-index.css`](./web-index.css) (from `apps/web/src/index.css`). The mobile
tokens live in [`lib/app/theme/tokens.dart`](../../lib/app/theme/tokens.dart).

> ✅ **The colour + type tokens are already identical** — mobile was ported
> _verbatim_ from the web CSS (verified hex-for-hex below). So a refactor does
> **not** re-do the palette; it aligns **components and motifs** to the richer
> web set (see the component inventory at the end).

---

## 1. Colour tokens — role-based, dual theme

Tokens are split by **role**, not by hue, so the same component reads well in
both themes. Switching is driven by `.dark` on `<html>` (web) / `Brightness`
(mobile). In Flutter, read them with `AppTokens.of(context)`.

| Role                  | Web var               | Light     | Dark      | Mobile `AppTokens` | Status       |
| --------------------- | --------------------- | --------- | --------- | ------------------ | ------------ |
| Page background       | `--color-stage`       | `#F6F5F1` | `#0A0B08` | `stage`            | ✅ identical |
| Card background       | `--color-surface`     | `#FFFFFF` | `#14150F` | `surface`          | ✅           |
| Inset / muted surface | `--color-surface-2`   | `#EFEEE8` | `#1C1E16` | `surface2`         | ✅           |
| Hairline border       | `--color-line`        | `#E6E4DA` | `#2B2D23` | `line`             | ✅           |
| Stronger border       | `--color-line-strong` | `#D4D2C6` | `#3B3E30` | `lineStrong`       | ✅           |
| Primary text          | `--color-ink`         | `#1A1A16` | `#F3F4EC` | `ink`              | ✅           |
| Secondary text        | `--color-ink-soft`    | `#5C5B52` | `#A4A698` | `inkSoft`          | ✅           |
| Tertiary text         | `--color-ink-faint`   | `#8D8B80` | `#6C6E60` | `inkFaint`         | ✅           |
| Accent (lime-as-text) | `--color-accent`      | `#4D7C0F` | `#C6FF3D` | `accent`           | ✅           |
| Brand fill            | `--color-lime`        | `#C6FF3D` | `#C6FF3D` | `lime`             | ✅           |
| Brand fill (dim)      | `--color-lime-dim`    | `#AEE029` | `#AEE029` | `limeDim`          | ✅           |
| Text on lime          | `--color-on-lime`     | `#0F0F0D` | `#0F0F0D` | `onLime`           | ✅           |

**Key rules**

- `lime` / `on-lime` are **constant** across themes (brand fills + the text on top).
- `accent` is "lime as text": deep **olive `#4D7C0F`** on light (lime text on white
  fails contrast), full **lime** on dark.
- Dark neutrals carry a faint **green-black tint** (never pure `#000`, which reads
  as a generic/AI default).

**Mobile-only semantic tokens** (not in the web core — safe to keep):
`star` (earned-star amber: `#E8A33D` light / `#F0B84E` dark) and `improve`
("para la próxima" amber, never red: `#B4761F` / `#E0A83D`).

---

## 2. Typography

| Role                     | Family                             | Notes                                                                          |
| ------------------------ | ---------------------------------- | ------------------------------------------------------------------------------ |
| Titles / body            | **Inter** (`--font-sans`)          | `font-optical-sizing: auto`                                                    |
| Display                  | **Inter**, tightened               | `letter-spacing: -0.03em`, `font-feature-settings: "tnum"` — headlines/figures |
| Data / labels / eyebrows | **JetBrains Mono** (`--font-mono`) | engineered, editorial voice; use for numbers, eyebrows, timers                 |

Mobile: `AppFonts.sans = 'Inter'`, `AppFonts.mono = 'JetBrainsMono'` (bundled in
`assets/fonts/`). The "display" treatment (tight tracking + tabular figures) is
the pattern to apply to large numbers (WPM, timer, stars).

> Icons: the web uses **Material Symbols Rounded**; mobile uses Flutter's native
> `Icons.*_rounded` (same glyph language, zero extra weight).

---

## 3. Radii

| Token       | Web                    | Mobile `AppRadius` |
| ----------- | ---------------------- | ------------------ |
| Card        | `16px` (`.glass-card`) | `card = 20`        |
| Pane / chip | `12px`                 | `chip = 12`        |
| Button      | —                      | `button = 16`      |
| Pill        | `999px`                | `pill = 999`       |
| Auth card   | `18px`                 | —                  |

⚠️ Minor delta: mobile cards use **20** vs web **16**. Align to taste — pick one
value and use it everywhere for consistency.

---

## 4. Motifs (signature visuals)

| Motif                                               | Web (class / keyframes)                    | Mobile widget                         | Status                                 |
| --------------------------------------------------- | ------------------------------------------ | ------------------------------------- | -------------------------------------- |
| **Equalizer voice**                                 | `.eq-bar` / `@keyframes eq`                | `shared/brand/eq_waveform.dart`       | ✅                                     |
| **Aurora mesh** background                          | `.aurora-1..4` / `aurora-drift-*`          | `shared/brand/aurora_background.dart` | ✅                                     |
| **Glass card** (frost over drifting blob)           | `.glass-card` + `__blob` + `__pane`        | `shared/ui/glass_card.dart`           | ✅ (mobile skips live blur on the A12) |
| **Glow border** (rotating conic lime)               | `.glow-border` (Houdini `@property`)       | —                                     | 🔲 to evaluate                         |
| **Auth backdrop** (drifting light "blades" + grain) | `.auth-blade`, `.auth-grain`, `.auth-card` | —                                     | 🔲 web-only (login showcase)           |
| **Card rise / float** entrances                     | `.card-rise`, `.float-soft`                | `_Rise` in `report_screen.dart`       | ✅                                     |

All web motion respects `prefers-reduced-motion`. On the A12, mobile deliberately
**bakes glows** instead of live `backdrop-filter` (GPU cost) — keep that: match
the _look_, not the exact technique.

---

## 5. Component inventory (web) → refactor checklist

The web has a richer component set than the mobile. Use these as the **visual/UX
reference** when refactoring Flutter screens (they are React `.tsx`, so port the
_look & behaviour_, not the code). The full source is copied into this repo under
[`./web-components/`](./web-components/) (originals live at
`oratorIA-frontend/apps/web/src/components/`).

### Reports / results

- `reports/aurora-background.tsx` → mobile `aurora_background.dart` ✅
- `reports/glass-card.tsx` → mobile `glass_card.dart` ✅
- `reports/score-card.tsx`, `reports/improvements-list.tsx`,
  `reports/insight-carousel.tsx` → mobile `report_screen.dart` (stars, feedback
  cards, bento) — **partial**; the insight carousel is a candidate to port.

### Practice / session

- `practice/final-report.tsx` → `report_screen.dart` ✅
- `practice/audio-orb.tsx`, `practice/radial-recorder.tsx` → La Banca + eq in
  `session_screen.dart` — **partial**
- `audio/waveform.tsx` → `eq_waveform.dart` ✅
- `practice/live-timer.tsx`, `practice/floating-metrics.tsx`,
  `practice/live-fillers-hud.tsx`, `practice/active-transcript.tsx`,
  `practice/analyzing-state.tsx`, `practice/pre-session.tsx`,
  `practice/control-bar.tsx` → session HUD — **evaluate for mobile parity**

### Dashboard (maps to mobile hub / progress)

- `dashboard/hero-card.tsx`, `last-session-card.tsx`, `recommendation-banner.tsx`,
  `routes-grid.tsx`, `quick-actions.tsx`, `stats-grid.tsx`, `progress-chart.tsx`,
  `score-journey.tsx`, `session-timeline.tsx`, `sessions-list.tsx`,
  `empty-state.tsx`, `theme-toggle.tsx`, `topbar.tsx`, `sidebar.tsx`
  → mobile `hub/` + `progress/` — **richest gap**; the dashboard cards and charts
  are the strongest reference for elevating the mobile hub/progress screens.

### Auth (web-only for now)

- `auth/*` — the mobile uses local profiles (no auth), so these are reference-only.

---

## 6. Using the system in Flutter

```dart
final t = AppTokens.of(context);        // resolves light/dark by Brightness
Container(color: t.surface, ...);        // role tokens
Text('123', style: TextStyle(fontFamily: AppFonts.mono)); // data → mono
BorderRadius.circular(AppRadius.card);    // shared radii
```

- Never hard-code hex — always go through `AppTokens` so light/dark stay in sync.
- Numbers, timers, eyebrows → **mono**; everything else → **Inter**.
- Match motifs by _look_ (baked glows on-device), not by copying web GPU tricks.

**When the web design system changes, update [`web-index.css`](./web-index.css)
here and re-sync `tokens.dart`** so the two platforms never drift.
