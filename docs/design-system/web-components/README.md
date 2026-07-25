# Web components — visual/UX reference (not buildable code)

These are the **web frontend's React components** (`oratorIA-frontend/apps/web/
src/components`), copied here verbatim so the mobile team has the design system's
**components in one place** when refactoring the Flutter UI.

> ⚠️ **Reference only.** These are `.tsx` (React + Tailwind v4). They do **not**
> compile in Flutter and are not imported by the app. Port the **look &
> behaviour**, not the code — read the JSX structure + the Tailwind classes, then
> rebuild the equivalent in Dart with `AppTokens` / `AppFonts` / `AppRadius`.

## How to read them

- The Tailwind class names (e.g. `bg-surface`, `text-ink-soft`, `text-accent`,
  `font-mono`) map 1:1 to the tokens defined in [`../web-index.css`](../web-index.css)
  — the same tokens the Flutter app already uses (see [`../DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md)).
- Only the component source is included — the app logic (`lib/`, `stores/`,
  Deepgram/Tavus integrations) was intentionally left out: it isn't part of the
  design system and could carry integration details.

## Where the refactor value is

The **`dashboard/`** components are the richest reference for elevating the mobile
**hub** and **"Mi progreso"** screens (hero-card, progress-chart, score-journey,
session-timeline, stats-grid, recommendation-banner). The **`practice/`** and
**`reports/`** components map to the mobile session and report screens.

See [`../DESIGN_SYSTEM.md` §5](../DESIGN_SYSTEM.md) for the full web→mobile mapping
with status (✅ done / partial / 🔲 to port).
