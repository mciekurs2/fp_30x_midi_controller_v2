import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers.dart';

part 'high_scores.g.dart';

/// Top scores per settings bucket, cached in memory so the HUD reads them
/// synchronously and rebuilds when a new score lands.
@Riverpod(keepAlive: true)
class HighScores extends _$HighScores {
  @override
  Map<String, List<int>> build() {
    _restore();
    return const {};
  }

  Future<void> _restore() async {
    final loaded = await ref.read(highScoreRepositoryProvider).loadAll();
    if (!ref.mounted) return;
    state = loaded;
  }

  /// The saved top scores for [key], highest first.
  List<int> top(String key) => state[key] ?? const [];

  Future<void> record(String key, int score) async {
    final top = await ref
        .read(highScoreRepositoryProvider)
        .record(key, score, state[key] ?? const []);
    if (!ref.mounted) return;
    state = {...state, key: top};
  }
}
