import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:oratoria_core/oratoria_core.dart';

import '../../adapters/coach/exercise_personalizer.dart';
import '../../app/config/feature_flags.dart';
import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../data/progress_impact.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/ui/eyebrow.dart';
import '../../shared/ui/glass_card.dart';

/// The payoff screen. Renders exactly what the design doc promises:
/// stars, one strength, one improvement, and the exercise's own verdict.
///
/// The raw 0–100 score is deliberately absent. It is stored for progress
/// tracking, but showing it invites a child to compare themselves with the
/// kid at the next desk, which is the fastest way to make a shy student stop
/// practising.
class ReportScreen extends StatelessWidget {
  final PracticeResult result;
  final VoidCallback onPracticeAgain;

  /// Starts the recommended next challenge. Null → the card just suggests it
  /// with no action (the tap is a thin, removable layer: pass null to "solo
  /// sugerir" without touching anything else).
  final void Function(Exercise exercise)? onStartExercise;

  /// The audience's follow-up question (the Agentes beat), written on-device by
  /// Gemma. Shown as a card here instead of a blocking screen before the report,
  /// so it's the "wow" without gating the payoff. Null → the card is omitted.
  final String? audienceQuestion;
  /// Needed only for `personalized-exercises`: with both present (and the
  /// flag on), the "próximo reto" card rewrites its own text in the
  /// background from the child's AI profile. Null → the card behaves exactly
  /// as before (static text), which is also what every existing call site
  /// that predates this feature gets for free.
  final Profile? profile;
  final LocalStore? store;

  /// Defaults to the real compile-time flag; overridable so tests can
  /// exercise the "on" path without flipping the production default.
  final bool personalizedExercises;

  /// Defaults to the production Gemma wiring when null; overridable in tests.
  final ExercisePersonalizer? exercisePersonalizer;

  const ReportScreen({
    super.key,
    required this.result,
    required this.onPracticeAgain,
    this.onStartExercise,
    this.audienceQuestion,
    this.profile,
    this.store,
    this.personalizedExercises = FeatureFlags.personalizedExercises,
    this.exercisePersonalizer,
  });

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;
    final t = AppTokens.of(context);

    // Word metrics (pace, fillers) are shown only when the transcript is both
    // trusted STT output AND long enough to mean anything — matching the coach,
    // which withholds its verdict below that bar. Otherwise a two-word clip
    // would print a confident "8 palabras / min".
    final showWords = result.voiceTextTrusted && result.voice.isMeaningful;

    // progress-impact-indicators: compares this practice (assumed already
    // saved as history[0] by session_screen.dart before this screen ever
    // builds) against the nearest older confiable entry. Purely derived from
    // already-persisted data — no Gemma call, no loading state.
    final impacts = (profile != null && store != null)
        ? compareToPrevious(store!.resultsFor(profile!.id), 0)
        : const <ProgressImpact>[];

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              _StarRow(stars: result.stars, level: result.levelLabel),
              const SizedBox(height: 24),
              if (feedback.goalMessage != null) ...[
                _GoalBanner(
                  met: feedback.goalMet ?? false,
                  message: feedback.goalMessage!,
                ),
                const SizedBox(height: 16),
              ],
              _Rise(
                index: 0,
                child: _FeedbackCard(
                  icon: Icons.emoji_events_rounded,
                  glow: t.lime,
                  accent: t.accent,
                  label: 'Lo que hiciste bien',
                  title: feedback.strengthTitle,
                  body: feedback.strengthBody,
                ),
              ),
              const SizedBox(height: 16),
              _Rise(
                index: 1,
                child: _FeedbackCard(
                  icon: Icons.lightbulb_rounded,
                  glow: t.improve,
                  accent: t.improve,
                  label: 'Para la próxima',
                  title: feedback.improvementTitle,
                  body: feedback.improvementBody,
                ),
              ),
              const SizedBox(height: 24),
              // Only show numbers we actually earned: pace and fillers need a
              // trusted transcript, pauses a real measurement, eye contact the
              // camera. With none of them we simply omit the section rather than
              // print placeholder figures.
              if (showWords ||
                  result.pausesTrusted ||
                  result.body.hasData) ...[
                const Eyebrow('Tus números'),
                const SizedBox(height: 12),
                _MetricsBento(
                  voice: result.voice,
                  body: result.body,
                  voiceTextTrusted: showWords,
                  pausesTrusted: result.pausesTrusted,
                ),
                const SizedBox(height: 28),
              ],
              // Honest comparison against the last confiable practice for
              // each dimension — omitted entirely when there's nothing real
              // to compare against yet.
              if (impacts.isNotEmpty) ...[
                _ImpactCard(impacts: impacts),
                const SizedBox(height: 28),
              ],
              // "What I heard" — the exact words the STT recognised. Shown only
              // when the transcript is trusted real speech, so the sample
              // fallback is never passed off as the child's words. This is the
              // honest proof that the app actually listened.
              if (result.voiceTextTrusted &&
                  result.transcript.trim().isNotEmpty) ...[
                _HeardCard(transcript: result.transcript.trim()),
                const SizedBox(height: 28),
              ],
              // The audience's follow-up — the Agentes "wow": an on-device AI
              // that listened and wants to hear more, no internet. A card, not a
              // gate, so it never blocks the payoff.
              if (audienceQuestion != null &&
                  audienceQuestion!.trim().isNotEmpty) ...[
                _AudienceCard(question: audienceQuestion!.trim()),
                const SizedBox(height: 28),
              ],
              // The next challenge, chosen from the weakest trusted dimension —
              // the primary call to action (directed practice). Always renders.
              _NextChallengeCard(
                suggestion: suggestNextChallenge(result),
                onStart: onStartExercise,
                profile: profile,
                store: store,
                personalizeEnabled: personalizedExercises,
                personalizer: exercisePersonalizer,
              ),
              const SizedBox(height: 8),
              // Secondary: free choice back at the chooser — autonomy matters.
              TextButton.icon(
                onPressed: onPracticeAgain,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Practicar otra vez'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Staggered translateY + fade entrance — the web's card-rise, cheap on the A12.
class _Rise extends StatelessWidget {
  final int index;
  final Widget child;

  const _Rise({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 90),
      curve: Curves.easeOutCubic,
      // Pass the real content through as the builder's `child` so it is built
      // once and actually rendered. Without this, `c` is null and the wrapped
      // widget (e.g. the feedback cards) silently vanishes.
      child: child,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  final String level;

  const _StarRow({required this.stars, required this.level});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final earned = i < stars;
            // Earned stars pop in sequence with a spring overshoot.
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + i * 120),
              curve: Curves.elasticOut,
              builder: (context, v, _) => Transform.scale(
                scale: earned ? v : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    earned ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 46,
                    color: earned ? t.star : t.line,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(level, style: Theme.of(context).textTheme.displaySmall),
      ],
    );
  }
}

class _GoalBanner extends StatelessWidget {
  final bool met;
  final String message;

  const _GoalBanner({required this.met, required this.message});

  @override
  Widget build(BuildContext context) {
    // A missed goal is shown in the same calm tone as a met one — the wording
    // carries the difference, not an alarm colour.
    final t = AppTokens.of(context);
    final color = met ? t.accent : t.improve;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.flag_rounded,
              color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// The recommended next challenge — the report's primary CTA. The copy is
/// chosen by [ChallengeSuggestion.kind] so a proxy or a repeat never overclaims.
/// When [onStart] is null it degrades to a plain suggestion (the tap is a thin,
/// removable layer).
///
/// Stateful only for `personalized-exercises`: on mount it may kick off (in
/// the background, never blocking this build) a rewrite of the recommended
/// exercise's title/prompt/hint from the child's AI profile. The button
/// always starts [suggestion.exercise] — the untouched original — so
/// "Continuar" never waits on Gemma and the next session's scoring/duration
/// never changes; only the text shown here is cosmetic and swappable.
class _NextChallengeCard extends StatefulWidget {
  final ChallengeSuggestion suggestion;
  final void Function(Exercise exercise)? onStart;
  final Profile? profile;
  final LocalStore? store;
  final bool personalizeEnabled;
  final ExercisePersonalizer? personalizer;

  const _NextChallengeCard({
    required this.suggestion,
    this.onStart,
    this.profile,
    this.store,
    this.personalizeEnabled = false,
    this.personalizer,
  });

  @override
  State<_NextChallengeCard> createState() => _NextChallengeCardState();
}

class _NextChallengeCardState extends State<_NextChallengeCard> {
  PersonalizedExercise? _personalized;

  @override
  void initState() {
    super.initState();
    _maybePersonalize();
  }

  void _maybePersonalize() {
    final profile = widget.profile;
    final store = widget.store;
    if (!widget.personalizeEnabled || profile == null || store == null) return;

    final ex = widget.suggestion.exercise;
    if (ex.id == 'e-libre') return; // "Práctica libre" is never reescrita.

    final cached = store.getPersonalizedExercise(profile.id, ex.id);
    if (cached != null) {
      // Already personalized in a past session — show it, no new Gemma call.
      setState(() => _personalized = cached);
      return;
    }

    final aiProfile = store.getAiProfile(profile.id);
    if (!_hasRealProfileContent(aiProfile)) return;

    final personalizer = widget.personalizer ?? ExercisePersonalizer.gemma();
    personalizer.personalize(ex, aiProfile).then((out) async {
      if (out == null) return;
      await store.savePersonalizedExercise(profile.id, ex.id, out);
      if (mounted) setState(() => _personalized = out);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // Always the untouched original — the personalized text below is purely
    // cosmetic and never leaks into what "Continuar" actually starts.
    final ex = widget.suggestion.exercise;
    final title = _personalized?.title ?? ex.title;
    final hint = _personalized?.hint ?? ex.targetHint;
    final dim = widget.suggestion.forDimension?.label ?? '';
    final (eyebrow, body, cta) = _copy(dim, title: title, hint: hint);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow, color: t.accent),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: t.inkSoft, height: 1.35)),
          if (widget.onStart != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onStart!(ex),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(cta),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// (eyebrow, body, cta) per kind — honest wording: proxy only "helps with",
  /// diagnostic invents no cause, reinforce frames repetition as coaching.
  (String, String, String) _copy(
    String dim, {
    required String title,
    required String hint,
  }) =>
      switch (widget.suggestion.kind) {
        SuggestionKind.causal => (
            'Tu próximo reto',
            'Tu punto flojo fue tu $dim, y este reto lo entrena. ¡Vamos por eso!',
            'Empezar $title',
          ),
        SuggestionKind.reinforce => (
            'Sigue puliendo tu $dim',
            'Todavía puedes mejorarlo. Repite este reto — esta vez: $hint',
            'Repetir $title',
          ),
        SuggestionKind.proxy => (
            'Tu próximo reto',
            'Un reto que te ayuda con tus $dim.',
            'Empezar $title',
          ),
        SuggestionKind.diagnostic => (
            'Sigue calentando',
            'Un buen reto para tomar impulso y que te escuchemos mejor.',
            'Empezar $title',
          ),
      };
}

/// Gate before spending a Gemma call: an empty/near-empty AI profile (right
/// after the child's first practice) would just make the model invent
/// something generic. `LocalStore` stores this as a JSON string; parsed
/// defensively since it may be model output from a small on-device LLM.
bool _hasRealProfileContent(String? aiProfile) {
  if (aiProfile == null || aiProfile.trim().isEmpty) return false;
  try {
    final decoded = jsonDecode(aiProfile);
    if (decoded is! Map<String, dynamic>) return false;
    bool nonEmptyList(dynamic v) => v is List && v.isNotEmpty;
    return nonEmptyList(decoded['interests']) ||
        nonEmptyList(decoded['strengths']);
  } catch (_) {
    return false;
  }
}

/// "Lo que escuché" — the real transcript, proof the app listened. Deliberately
/// plain and quiet: it is not a score, just the words, so the child (and a
/// sceptical judge) can see the on-device STT actually understood them.
class _HeardCard extends StatelessWidget {
  final String transcript;

  const _HeardCard({required this.transcript});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hearing_rounded, size: 16, color: t.inkSoft),
            const SizedBox(width: 8),
            const Eyebrow('Lo que escuché'),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: t.line),
          ),
          child: Text(
            '“$transcript”',
            style: TextStyle(
              color: t.inkSoft,
              fontSize: 15,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

/// The audience's follow-up question — the Agentes beat, folded into the report
/// as a quiet card instead of a blocking screen. On-device Gemma wrote it after
/// "listening", so it reads as the room leaning in, not a form to dismiss.
class _AudienceCard extends StatelessWidget {
  final String question;

  const _AudienceCard({required this.question});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, size: 16, color: t.accent),
            const SizedBox(width: 8),
            const Eyebrow('Tu público pregunta'),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: t.accent.withValues(alpha: 0.22)),
          ),
          child: Text(
            '“$question”',
            style: text.titleMedium?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final IconData icon;
  final Color glow; // baked radial glow behind the glass
  final Color accent; // icon + eyebrow tint
  final String label;
  final String title;
  final String body;

  const _FeedbackCard({
    required this.icon,
    required this.glow,
    required this.accent,
    required this.label,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // A pre-baked glow behind the glass card — the "glass over a colored blob"
    // look from the web, with no live BackdropFilter (A12-safe).
    return Stack(
      children: [
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [glow.withValues(alpha: 0.35), glow.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        GlassCard(
          accentEdge: accent.withValues(alpha: 0.28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Eyebrow(label, color: accent),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: text.titleLarge),
              const SizedBox(height: 8),
              Text(body, style: text.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

/// A neutral, factual comparison against the last confiable practice per
/// dimension — deliberately no "you improved!" framing: a lower filler rate
/// is unambiguously better, but pace has a comfortable range, not a
/// direction, so the honest move is to state the numbers and let the
/// strength/improvement cards above carry the verdict.
class _ImpactCard extends StatelessWidget {
  final List<ProgressImpact> impacts;

  const _ImpactCard({required this.impacts});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Comparado con tu práctica anterior'),
          const SizedBox(height: 8),
          for (final i in impacts)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(describeImpact(i), style: TextStyle(color: t.inkSoft)),
            ),
        ],
      ),
    );
  }
}

/// Bento metrics — one hero cell (rhythm) spanning full width, plus a row of
/// supporting cells. Numbers in tabular mono so they read like data.
class _MetricsBento extends StatelessWidget {
  final ParaverbalMetrics voice;
  final BodyMetrics body;

  /// When false, pace and fillers are omitted — the transcript was the sample
  /// fallback, so those figures would be invented.
  final bool voiceTextTrusted;

  /// When false, pauses are omitted — they were not measured from the audio.
  final bool pausesTrusted;

  const _MetricsBento({
    required this.voice,
    required this.body,
    this.voiceTextTrusted = true,
    this.pausesTrusted = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    // Trusted metrics only, in display priority. The first becomes the hero
    // cell; the rest fill the row. Ritmo leads when we have it, otherwise a
    // real signal (eye contact, pauses) is promoted so the section never leads
    // with a blank.
    final metrics = <(String, String, String)>[
      if (voiceTextTrusted)
        (
          'Ritmo',
          '${voice.wordsPerMinute.round()}',
          // When the clip ran past the STT window, the rate is an honest
          // estimate of the opening — say so instead of implying the whole run.
          voice.rateWindowCapped
              ? 'palabras / min · primeros 30 s'
              : 'palabras / min',
        ),
      if (body.hasData)
        ('Mirada', '${(body.eyeContactRatio * 100).round()}%', 'del tiempo'),
      if (pausesTrusted) ('Pausas', '${voice.awkwardPauseCount}', 'largas'),
      if (voiceTextTrusted) ('Muletillas', '${voice.fillerCount}', 'en total'),
    ];

    if (metrics.isEmpty) return const SizedBox.shrink();

    final hero = metrics.first;
    final rest = metrics.skip(1).toList();

    return Column(
      children: [
        _BentoCell(
          label: hero.$1,
          value: hero.$2,
          unit: hero.$3,
          accent: t.accent,
          hero: true,
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < rest.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _BentoCell(
                    label: rest[i].$1,
                    value: rest[i].$2,
                    accent: t.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _BentoCell extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color accent;
  final bool hero;

  const _BentoCell({
    required this.label,
    required this.value,
    required this.accent,
    this.unit,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: hero ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value, style: monoFigure(color: accent, size: hero ? 40 : 24)),
          const SizedBox(width: 10),
          // Expanded so the label/unit column is width-bounded and the unit can
          // wrap. Without it the unit lays out single-line at intrinsic width;
          // the longer "primeros 30 s" disclaimer would then overflow and get
          // clipped under text scaling — hiding the caveat while the number
          // stays visible, which would be dishonest.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                    fontSize: hero ? 16 : 13,
                  ),
                ),
                if (unit != null)
                  Text(
                    unit!,
                    softWrap: true,
                    maxLines: 2,
                    style: TextStyle(color: t.inkFaint, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
