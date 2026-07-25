import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_core/oratoria_core.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/presentation/report/report_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = Profile(id: 'p1', name: 'Ana', avatarKey: '🦊');

PracticeResult _resultWithVoice({
  required double wpm,
  required double fillerRate,
}) {
  final voice = ParaverbalMetrics(
    wordCount: 60,
    fillerCount: fillerRate.round(),
    wordsPerMinute: wpm,
    fillerRate: fillerRate,
    longestPause: Duration.zero,
    awkwardPauseCount: 0,
    speakingDuration: const Duration(seconds: 60),
  );
  const feedback = CoachFeedback(
    strengthDimension: Dimension.pace,
    strengthTitle: 'Buen ritmo',
    strengthBody: 'x',
    improvementDimension: Dimension.fillers,
    improvementTitle: 'y',
    improvementBody: 'z',
    source: FeedbackSource.ruleBased,
  );
  return PracticeResult(
    exercise: Exercise.free,
    voice: voice,
    body: BodyMetrics.none,
    feedback: feedback,
    score: 70,
    stars: 3,
    levelLabel: 'Bien',
    voiceTextTrusted: true,
    pausesTrusted: true,
    transcript: 'algo que dijo el niño',
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('shows no comparison when there is no prior confiable practice',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    // The just-finished practice is the ONLY entry in history.
    await store.saveResult(
      _profile.id,
      const SavedResult(
        exerciseId: 'e-libre',
        score: 70,
        stars: 3,
        atMillis: 100,
        wordsPerMinute: 118,
        fillerRate: 3,
      ),
    );

    await _pump(
      tester,
      ReportScreen(
        result: _resultWithVoice(wpm: 118, fillerRate: 3),
        onPracticeAgain: () {},
        profile: _profile,
        store: store,
      ),
    );

    expect(find.textContaining('Pasaste de'), findsNothing);
  });

  testWidgets('shows the comparison against the immediately prior practice',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.saveResult(
      _profile.id,
      const SavedResult(
        exerciseId: 'e-libre',
        score: 60,
        stars: 3,
        atMillis: 50,
        wordsPerMinute: 95,
        fillerRate: 6,
      ),
    );
    // The just-finished practice, saved after the one above (newer atMillis).
    await store.saveResult(
      _profile.id,
      const SavedResult(
        exerciseId: 'e-libre',
        score: 70,
        stars: 3,
        atMillis: 100,
        wordsPerMinute: 118,
        fillerRate: 3,
      ),
    );

    await _pump(
      tester,
      ReportScreen(
        result: _resultWithVoice(wpm: 118, fillerRate: 3),
        onPracticeAgain: () {},
        profile: _profile,
        store: store,
      ),
    );

    expect(find.textContaining('de 95 a 118'), findsOneWidget);
  });

  testWidgets('shows nothing without profile/store (predates this feature)',
      (tester) async {
    await _pump(
      tester,
      ReportScreen(
        result: _resultWithVoice(wpm: 118, fillerRate: 3),
        onPracticeAgain: () {},
      ),
    );

    expect(find.textContaining('Pasaste de'), findsNothing);
  });
}
