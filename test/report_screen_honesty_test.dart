import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_core/oratoria_core.dart';
import 'package:oratoria_kids/presentation/report/report_screen.dart';

/// Locks the report's honesty invariants — the two defects found this session:
///  1. the coach feedback cards must actually render (the `_Rise` bug hid them);
///  2. word metrics (pace/fillers) appear only for trusted, meaningful speech,
///     and a rate computed over Whisper's 30 s window carries its disclaimer.
PracticeResult _result({
  required bool voiceTextTrusted,
  required bool pausesTrusted,
  bool rateWindowCapped = false,
  bool meaningful = true,
  bool bodyHasData = false,
  String transcript = 'hola me llamo ana y les voy a contar sobre mi perro',
}) {
  final voice = ParaverbalMetrics(
    wordCount: meaningful ? 60 : 2,
    fillerCount: 0,
    wordsPerMinute: 120,
    fillerRate: 0,
    longestPause: Duration.zero,
    awkwardPauseCount: 1,
    speakingDuration: Duration(seconds: meaningful ? 60 : 3),
    rateWindowCapped: rateWindowCapped,
  );
  final body = bodyHasData
      ? const BodyMetrics(
          eyeContactRatio: 0.8,
          smileRatio: 0.5,
          uprightRatio: 0.8,
          framesAnalyzed: 400,
        )
      : BodyMetrics.none;
  const feedback = CoachFeedback(
    strengthDimension: Dimension.pace,
    strengthTitle: 'Buen ritmo',
    strengthBody: 'Mantuviste un ritmo agradable de principio a fin.',
    improvementDimension: Dimension.pauses,
    improvementTitle: 'Cuida las pausas',
    improvementBody: 'Hubo un par de silencios largos que cortaron el hilo.',
    source: FeedbackSource.ruleBased,
  );
  return PracticeResult(
    exercise: Exercise.free,
    voice: voice,
    body: body,
    feedback: feedback,
    score: 80,
    stars: 4,
    levelLabel: 'Muy bien',
    voiceTextTrusted: voiceTextTrusted,
    pausesTrusted: pausesTrusted,
    transcript: transcript,
  );
}

Future<void> _pump(
  WidgetTester tester,
  PracticeResult r, {
  void Function(Exercise)? onStart,
  String? audienceQuestion,
}) async {
  // Tall surface so the whole report (a lazy ListView) is laid out — otherwise
  // sections near the bottom (e.g. "Lo que escuché") are never built and can't
  // be found.
  tester.view.physicalSize = const Size(1400, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: ReportScreen(
        result: r,
        onPracticeAgain: () {},
        onStartExercise: onStart,
        audienceQuestion: audienceQuestion,
      ),
    ),
  );
  // Advance past the feedback cards' rise animation without settling — the
  // aurora backdrop animates forever, so pumpAndSettle would hang.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('always renders the coach strength + improvement (the _Rise fix)',
      (tester) async {
    await _pump(tester, _result(voiceTextTrusted: true, pausesTrusted: true));

    expect(find.text('Buen ritmo'), findsOneWidget);
    expect(find.text('Cuida las pausas'), findsOneWidget);
  });

  testWidgets('a capped rate shows the "primeros 30 s" disclaimer',
      (tester) async {
    await _pump(
      tester,
      _result(voiceTextTrusted: true, pausesTrusted: true, rateWindowCapped: true),
    );

    expect(find.textContaining('primeros 30 s'), findsOneWidget);
  });

  testWidgets('an uncapped rate shows a plain unit, no disclaimer',
      (tester) async {
    await _pump(tester, _result(voiceTextTrusted: true, pausesTrusted: true));

    expect(find.textContaining('palabras / min'), findsOneWidget);
    expect(find.textContaining('primeros 30 s'), findsNothing);
  });

  testWidgets('an untrusted transcript hides all word metrics but keeps feedback',
      (tester) async {
    await _pump(
      tester,
      _result(voiceTextTrusted: false, pausesTrusted: false),
    );

    // No fabricated pace when the STT could not be trusted...
    expect(find.textContaining('palabras / min'), findsNothing);
    // ...but the child still gets their coaching.
    expect(find.text('Buen ritmo'), findsOneWidget);
  });

  testWidgets('trusted-but-too-short speech still hides word metrics',
      (tester) async {
    await _pump(
      tester,
      _result(voiceTextTrusted: true, pausesTrusted: false, meaningful: false),
    );

    expect(find.textContaining('palabras / min'), findsNothing);
  });

  testWidgets('trusted speech shows "Lo que escuché" with the real transcript',
      (tester) async {
    await _pump(
      tester,
      _result(
        voiceTextTrusted: true,
        pausesTrusted: true,
        transcript: 'mi animal favorito es el gato',
      ),
    );

    // Eyebrow renders uppercase; the transcript keeps its case.
    expect(find.textContaining('LO QUE ESCUCHÉ'), findsOneWidget);
    expect(find.textContaining('mi animal favorito es el gato'), findsOneWidget);
  });

  testWidgets('an untrusted transcript is NOT shown as "Lo que escuché"',
      (tester) async {
    await _pump(
      tester,
      _result(
        voiceTextTrusted: false,
        pausesTrusted: false,
        transcript: 'texto de muestra que no debe mostrarse',
      ),
    );

    expect(find.textContaining('LO QUE ESCUCHÉ'), findsNothing);
    expect(find.textContaining('texto de muestra'), findsNothing);
  });

  // --- Audience follow-up (the Agentes beat) rides ON the report as a card,
  // not a blocking screen before it. ---

  testWidgets('shows the audience follow-up as a card when one was asked',
      (tester) async {
    await _pump(
      tester,
      _result(voiceTextTrusted: true, pausesTrusted: true),
      audienceQuestion: '¿Y qué fue lo más difícil de todo eso?',
    );

    // Eyebrow renders uppercase; the question keeps its case.
    expect(find.textContaining('TU PÚBLICO PREGUNTA'), findsOneWidget);
    expect(
      find.textContaining('¿Y qué fue lo más difícil de todo eso?'),
      findsOneWidget,
    );
  });

  testWidgets('omits the audience card when no question was asked',
      (tester) async {
    await _pump(tester, _result(voiceTextTrusted: true, pausesTrusted: true));

    expect(find.textContaining('TU PÚBLICO PREGUNTA'), findsNothing);
  });

  // --- Next-challenge card. The card lives on the same screen the _Rise bug
  // hid, so "does it actually paint?" is the non-negotiable net. ---

  testWidgets('ALWAYS renders the next-challenge card as the primary CTA',
      (tester) async {
    Exercise? started;
    // Default improvement dimension is pauses -> proxy -> Cuenta un cuento.
    await _pump(
      tester,
      _result(voiceTextTrusted: true, pausesTrusted: true),
      onStart: (e) => started = e,
    );

    // (FilledButton.icon is a private subtype, so match the CTA by its text.)
    final cta = find.text('Empezar Cuenta un cuento');
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    expect(started?.id, 'e-cuento'); // the tap starts exactly that reto
  });

  testWidgets('the CTA is absent (severable) when onStart is null', (tester) async {
    await _pump(tester, _result(voiceTextTrusted: true, pausesTrusted: true));
    // Suggestion still shows, but there is no start button — "solo sugerir".
    expect(find.textContaining('Cuenta un cuento'), findsWidgets);
    expect(find.text('Empezar Cuenta un cuento'), findsNothing);
  });

  testWidgets(
      'invariant: confident weakness -> weakness reto; nothing measured -> diagnostic',
      (tester) async {
    // Gate TRUE (trusted) -> the card targets the weakness (pauses -> Cuento),
    // never the diagnostic Preséntate. Asserted via the CTA to avoid the
    // Eyebrow's uppercasing.
    await _pump(tester, _result(voiceTextTrusted: true, pausesTrusted: true),
        onStart: (_) {});
    expect(find.text('Empezar Cuenta un cuento'), findsOneWidget);
    expect(find.text('Empezar Preséntate'), findsNothing);

    // Gate FALSE (nothing measured with confidence) -> diagnostic, Preséntate.
    await _pump(tester, _result(voiceTextTrusted: false, pausesTrusted: false),
        onStart: (_) {});
    expect(find.text('Empezar Preséntate'), findsOneWidget);
  });
}
