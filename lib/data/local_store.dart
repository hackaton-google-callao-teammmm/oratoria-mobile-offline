import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A local profile on a shared classroom/family tablet. NOT authentication —
/// no password, no email — just a name and an avatar to keep each child's
/// progress separate on the same device.
class Profile {
  final String id;
  final String name;
  final String avatarKey;

  const Profile({required this.id, required this.name, required this.avatarKey});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'avatarKey': avatarKey};

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarKey: j['avatarKey'] as String,
      );
}

/// One saved practice result — the source for "Mi progreso". The raw score is
/// stored (never shown); the UI renders stars.
class SavedResult {
  final String exerciseId;
  final int score;
  final int stars;
  final int atMillis; // epoch millis, passed in (Date.now is unavailable here)

  const SavedResult({
    required this.exerciseId,
    required this.score,
    required this.stars,
    required this.atMillis,
  });

  Map<String, dynamic> toJson() =>
      {'e': exerciseId, 's': score, 'st': stars, 't': atMillis};

  factory SavedResult.fromJson(Map<String, dynamic> j) => SavedResult(
        exerciseId: j['e'] as String,
        score: j['s'] as int,
        stars: j['st'] as int,
        atMillis: j['t'] as int,
      );
}

/// A cosmetic rewrite of one exercise's title/prompt/hint — never its `id`,
/// `targetSkill` or `targetDuration`. Produced by Gemma from the child's AI
/// profile (see `personalized-exercises`), one exercise at a time.
class PersonalizedExercise {
  final String title;
  final String prompt;
  final String hint;

  const PersonalizedExercise({
    required this.title,
    required this.prompt,
    required this.hint,
  });

  Map<String, dynamic> toJson() =>
      {'title': title, 'prompt': prompt, 'hint': hint};

  factory PersonalizedExercise.fromJson(Map<String, dynamic> j) =>
      PersonalizedExercise(
        title: j['title'] as String,
        prompt: j['prompt'] as String,
        hint: j['hint'] as String,
      );
}

/// Fully-local persistence for profiles and results, backed by
/// shared_preferences (JSON). Chosen over drift deliberately: the data is a
/// handful of profiles and a list of results per child — a SQLite database
/// plus code generation would be over-engineering, and drift's codegen
/// deadlocks on this Dart toolchain. Same outcome, zero build risk, offline.
class LocalStore {
  static const _kProfiles = 'profiles';
  static String _resultsKey(String profileId) => 'results.$profileId';
  static String _aiProfileKey(String profileId) => 'aiProfile.$profileId';
  static String _personalizedExercisesKey(String profileId) =>
      'personalizedExercises.$profileId';

  final SharedPreferences _prefs;
  const LocalStore(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  // ---- Profiles ----

  List<Profile> profiles() {
    final raw = _prefs.getString(_kProfiles);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Profile> addProfile({
    required String id,
    required String name,
    required String avatarKey,
  }) async {
    final profile = Profile(id: id, name: name, avatarKey: avatarKey);
    final all = [...profiles(), profile];
    await _prefs.setString(
      _kProfiles,
      jsonEncode(all.map((p) => p.toJson()).toList()),
    );
    return profile;
  }

  Future<void> updateProfile({
    required String id,
    required String name,
    required String avatarKey,
  }) async {
    final all = [
      for (final p in profiles())
        if (p.id == id)
          Profile(id: id, name: name, avatarKey: avatarKey)
        else
          p,
    ];
    await _prefs.setString(
      _kProfiles,
      jsonEncode(all.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> deleteProfile(String id) async {
    final all = profiles().where((p) => p.id != id).toList();
    await _prefs.setString(
      _kProfiles,
      jsonEncode(all.map((p) => p.toJson()).toList()),
    );
    await _prefs.remove(_resultsKey(id));
    await _prefs.remove(_aiProfileKey(id));
    await _prefs.remove(_personalizedExercisesKey(id));
  }

  // ---- AI Profile ----

  String? getAiProfile(String profileId) {
    return _prefs.getString(_aiProfileKey(profileId));
  }

  Future<void> saveAiProfile(String profileId, String profileJson) async {
    await _prefs.setString(_aiProfileKey(profileId), profileJson);
  }

  // ---- Personalized exercises ----

  Map<String, PersonalizedExercise> getAllPersonalizedExercises(
    String profileId,
  ) {
    final raw = _prefs.getString(_personalizedExercisesKey(profileId));
    if (raw == null) return const {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (id, j) => MapEntry(
        id,
        PersonalizedExercise.fromJson(j as Map<String, dynamic>),
      ),
    );
  }

  PersonalizedExercise? getPersonalizedExercise(
    String profileId,
    String exerciseId,
  ) =>
      getAllPersonalizedExercises(profileId)[exerciseId];

  /// Upserts a single exercise's override without touching the others.
  Future<void> savePersonalizedExercise(
    String profileId,
    String exerciseId,
    PersonalizedExercise override,
  ) async {
    final all = {...getAllPersonalizedExercises(profileId)};
    all[exerciseId] = override;
    await _prefs.setString(
      _personalizedExercisesKey(profileId),
      jsonEncode(all.map((id, e) => MapEntry(id, e.toJson()))),
    );
  }

  // ---- Results ----

  List<SavedResult> resultsFor(String profileId) {
    final raw = _prefs.getString(_resultsKey(profileId));
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedResult.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.atMillis.compareTo(a.atMillis)); // newest first
  }

  Future<void> saveResult(String profileId, SavedResult result) async {
    final all = [...resultsFor(profileId), result];
    await _prefs.setString(
      _resultsKey(profileId),
      jsonEncode(all.map((r) => r.toJson()).toList()),
    );
  }
}
