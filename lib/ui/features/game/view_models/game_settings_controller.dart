import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers.dart';
import '../../../../domain/models/game_mode.dart';
import '../../../../domain/models/game_settings.dart';
import '../../../../domain/models/music_key.dart';
import '../../../../domain/models/song.dart';

part 'game_settings_controller.g.dart';

/// The last-used settings, restored on launch and saved on every change.
///
/// Kept alive: it is read imperatively from sheets that only exist while they
/// are open, so an auto-disposing provider would drop back to the defaults the
/// moment one closed.
@Riverpod(keepAlive: true)
class GameSettingsController extends _$GameSettingsController {
  @override
  GameSettings build() {
    _restore();
    return GameSettings();
  }

  Future<void> _restore() async {
    final restored = await ref.read(settingsRepositoryProvider).load();
    if (!ref.mounted) return;
    state = restored;
  }

  void setMode(GameMode mode) => _update(state.copyWith(mode: mode));

  void setDuration(int seconds) =>
      _update(state.copyWith(durationSeconds: seconds));

  void setUntimed(bool untimed) => _update(state.copyWith(untimed: untimed));

  void setChordKey(MusicKey key) => _update(state.copyWith(chordKey: key));

  void setSong(String asset) => _update(state.copyWith(songAsset: asset));

  void setHands(PlayHands hands) => _update(state.copyWith(hands: hands));

  /// An empty set is ignored rather than saved — [GameSettings] would fall back
  /// to its default pool anyway, which would read as the chips resetting.
  void setOctaves(Set<int> octaves) {
    if (octaves.isEmpty) return;
    _update(state.copyWith(octaves: octaves));
  }

  void _update(GameSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).save(next);
  }
}
