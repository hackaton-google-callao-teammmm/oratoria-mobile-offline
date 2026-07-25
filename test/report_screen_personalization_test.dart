import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_core/oratoria_core.dart';
import 'package:oratoria_kids/adapters/coach/exercise_personalizer.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/presentation/report/report_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = Profile(id: 'p1', name: 'Ana', avatarKey: '🦊');

PracticeResult _resultWeakOn(Dimension dim) {
  final voice = ParaverbalMetrics(
    wordCount: 60,
    fillerCount: 8,
    wordsPerMinute: 120,
    fillerRate: 8,
    longestPause: Duration.zero,
    awkwardPauseCount: 0,
    speakingDuration: const Duration(seconds: 60),
  );
  final feedback = CoachFeedback(
    strengthDimension: Dimension.pace,
    strengthTitle: 'Buen ritmo',
    strengthBody: 'x',
    improvementDimension: dim,
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
    transcript: 'me gustan los dinosaurios',
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  // Tall surface + no pumpAndSettle: the aurora backdrop animates forever.
  tester.view.physicalSize = const Size(1400, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(seconds: 1));
  // Let any chained Future.then()/setState from initState land.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('disabled flag: never personalizes even with a real profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.saveAiProfile(_profile.id, '{"interests":["dinosaurios"]}');
    var called = false;
    final personalizer = ExercisePersonalizer(rewrite: (_) async {
      called = true;
      return '{"title":"X","prompt":"Y","hint":"Z"}';
    });

    await _pump(
      tester,
      ReportScreen(
        result: _resultWeakOn(Dimension.fillers),
        onPracticeAgain: () {},
        profile: _profile,
        store: store,
        personalizedExercises: false,
        exercisePersonalizer: personalizer,
      ),
    );

    expect(find.text('Mi animal favorito'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('enabled but profile has no real content yet: no personalization',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    // No aiProfile saved at all — perfil recién nacido.
    var called = false;
    final personalizer = ExercisePersonalizer(rewrite: (_) async {
      called = true;
      return '{"title":"X","prompt":"Y","hint":"Z"}';
    });

    await _pump(
      tester,
      ReportScreen(
        result: _resultWeakOn(Dimension.fillers),
        onPracticeAgain: () {},
        profile: _profile,
        store: store,
        personalizedExercises: true,
        exercisePersonalizer: personalizer,
      ),
    );

    expect(find.text('Mi animal favorito'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets(
      'shows an already-cached override instantly, without calling the personalizer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.saveAiProfile(_profile.id, '{"interests":["dinosaurios"]}');
    await store.savePersonalizedExercise(
      _profile.id,
      'e-animal',
      const PersonalizedExercise(
        title: '¡Cuéntanos de tu T-Rex favorito!',
        prompt: 'Cuéntanos de tu dinosaurio favorito',
        hint: 'Respira antes de decir este.',
      ),
    );
    var called = false;
    final personalizer = ExercisePersonalizer(rewrite: (_) async {
      called = true;
      return '{"title":"NO","prompt":"NO","hint":"NO"}';
    });

    await _pump(
      tester,
      ReportScreen(
        result: _resultWeakOn(Dimension.fillers),
        onPracticeAgain: () {},
        profile: _profile,
        store: store,
        personalizedExercises: true,
        exercisePersonalizer: personalizer,
      ),
    );

    expect(find.text('¡Cuéntanos de tu T-Rex favorito!'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('personalizes in the background and updates the tile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.saveAiProfile(_profile.id, '{"interests":["dinosaurios"]}');
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async => '{"title":"¡Cuéntanos de tu T-Rex favorito!",'
          '"prompt":"Cuéntanos de tu dinosaurio favorito",'
          '"hint":"Respira antes de decir este."}',
    );

    await _pump(
      tester,
      ReportScreen(
        result: _resultWeakOn(Dimension.fillers),
        onPracticeAgain: () {},
        profile: _profile,
        store: store,
        personalizedExercises: true,
        exercisePersonalizer: personalizer,
      ),
    );

    expect(find.text('¡Cuéntanos de tu T-Rex favorito!'), findsOneWidget);
    expect(
      store.getPersonalizedExercise(_profile.id, 'e-animal')?.title,
      '¡Cuéntanos de tu T-Rex favorito!',
    );
  });

  testWidgets('Continuar always starts the ORIGINAL exercise, even after personalizing',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.saveAiProfile(_profile.id, '{"interests":["dinosaurios"]}');
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async => '{"title":"¡Cuéntanos de tu T-Rex favorito!",'
          '"prompt":"Cuéntanos de tu dinosaurio favorito",'
          '"hint":"Respira antes de decir este."}',
    );
    Exercise? started;

    await _pump(
      tester,
      ReportScreen(
        result: _resultWeakOn(Dimension.fillers),
        onPracticeAgain: () {},
        onStartExercise: (e) => started = e,
        profile: _profile,
        store: store,
        personalizedExercises: true,
        exercisePersonalizer: personalizer,
      ),
    );

    // The card now shows the personalized title...
    expect(find.text('¡Cuéntanos de tu T-Rex favorito!'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    // ...but "Continuar" started the ORIGINAL exercise, untouched.
    expect(started, isNotNull);
    expect(started!.id, 'e-animal');
    expect(started!.title, 'Mi animal favorito');
  });
}
