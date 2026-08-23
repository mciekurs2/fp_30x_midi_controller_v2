import '../services/preferences_service.dart';

/// Top scores per settings bucket (`GameSettings.highScoreKey`). Untimed rounds
/// have no bucket and are never stored.
class HighScoreRepository {
  const HighScoreRepository(this._prefs);

  final PreferencesService _prefs;

  static const _prefix = 'highscore_';
  static const _keep = 3;

  Future<Map<String, List<int>>> loadAll() async {
    final keys = await _prefs.keysWithPrefix(_prefix);
    return {
      for (final key in keys)
        key.substring(_prefix.length): await _prefs.getIntList(key) ?? const [],
    };
  }

  /// Files [score] into [key]'s top three, returning the bucket as it now
  /// stands, highest first.
  Future<List<int>> record(String key, int score, List<int> existing) async {
    final ranked = [...existing, score]..sort((a, b) => b.compareTo(a));
    final top = ranked.take(_keep).toList();
    await _prefs.setIntList('$_prefix$key', top);
    return top;
  }
}
