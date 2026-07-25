# OratorIA Kids

Oratory coaching for children that runs **entirely on the device**. No account,
no server, no internet. A child's voice never leaves the phone or tablet.

Architecture: [`../docs/flutter-app-architecture.md`](../docs/flutter-app-architecture.md)

## The rule that shapes everything

**80 % of the coaching value needs no AI.** Filler counts, pace and pause
analysis are arithmetic over a transcript. The AI layer (Gemma, on-device)
makes the wording _warmer_, not the product _functional_.

Any change that breaks the app when the model is absent is wrong, even if it
works on the developer's machine.

## Layout

```
oratoria_kids/
├── packages/oratoria_core/     ← pure Dart. No Flutter, no AI SDK, no I/O.
│   ├── lib/src/
│   │   ├── entities/           ParaverbalMetrics, BodyMetrics, Exercise,
│   │   │                       CoachFeedback, PracticeResult
│   │   ├── analysis/           SpanishFillers, ParaverbalAnalyzer, Scoring
│   │   ├── coach/              RuleBasedCoach  ← terminal fallback
│   │   ├── ports/              SpeechTranscriber, BodyLanguageAnalyzer,
│   │   │                       CoachFeedbackGenerator
│   │   └── usecases/           EvaluatePractice
│   └── test/                   48 tests, run in milliseconds
└── lib/
    ├── app/                    theme
    ├── di/                     CapabilityResolver, Capabilities
    ├── adapters/speech/        MockTranscriber (sherpa-onnx lands in phase 2)
    └── presentation/           home, report
```

`oratoria_core` is a separate package on purpose: it cannot import Flutter, so
the rules that produce the app's value are testable with `dart test` in
milliseconds — no emulator — and no plugin upgrade can break them.

## Commands

```bash
# Core logic — fast, no device
cd packages/oratoria_core && dart test && dart analyze

# App
flutter pub get
flutter analyze
flutter run                 # pick a device
flutter build apk --debug
```

Windows desktop needs the Visual Studio "Desktop development with C++"
workload; Android and iOS build without extra setup.

## Status

| Phase | Scope                                                      | State                                                |
| ----- | ---------------------------------------------------------- | ---------------------------------------------------- |
| **1** | Core engine, rule-based coach, report UI, exercise catalog | Core **done and tested**; microphone + drift pending |
| 2     | sherpa-onnx on-device STT                                  | Not started                                          |
| 3     | Camera + ML Kit body language                              | Not started                                          |
| 4     | flutter_gemma + LAN adapters                               | Not started                                          |

Today the app runs the complete pipeline — analysis → scoring → coaching →
report — against a canned transcript via `MockTranscriber`. Swapping in the
real microphone changes one binding; no screen and no domain code moves,
because everything talks to ports.

## Invariants worth protecting

These are enforced by tests in `packages/oratoria_core/test/`. If you break
one, the suite tells you:

- `RuleBasedCoach` never throws and never returns empty feedback, for any
  input — including zero-length, negative and absurd values.
- A run too short to judge yields encouragement, not a low score.
- Body-language dimensions are ignored entirely when the camera produced no
  data; a child is never marked down for a camera that was off.
- `"este"` used as a demonstrative (`"de este modo"`) is not counted as a
  filler. Flagging a legitimate word destroys trust in every other number.
- The raw 0–100 score is stored but never rendered; the UI shows stars.
