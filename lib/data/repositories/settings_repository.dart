import '../../domain/models/game_mode.dart';
import '../../domain/models/game_settings.dart';
import '../../domain/models/music_key.dart';
import '../../domain/models/song.dart';
import '../services/preferences_service.dart';

/// Reads and writes the last-used [GameSettings]. Every field falls back to its
/// default when absent or unrecognised, so a fresh install — or a store written
/// by a build that spelled an enum differently — still opens on valid settings.
class SettingsRepository {
  const SettingsRepository(this._prefs);

  final PreferencesService _prefs;

  static const _prefix = 'gamesettings_';

  Future<GameSettings> load() async {
    final defaults = GameSettings();
    final octaves = (await _prefs.getIntList('${_prefix}octaves'))?.toSet();
    final fifths = await _prefs.getInt('${_prefix}chordKeyFifths');
    final tonality = _byName(
      Tonality.values,
      await _prefs.getString('${_prefix}chordKeyTonality'),
    );

    return GameSettings(
      mode:
          _byName(GameMode.values, await _prefs.getString('${_prefix}mode')) ??
          defaults.mode,
      octaves: (octaves == null || octaves.isEmpty) ? defaults.octaves : octaves,
      durationSeconds:
          await _prefs.getInt('${_prefix}duration') ?? defaults.durationSeconds,
      untimed: await _prefs.getBool('${_prefix}untimed') ?? defaults.untimed,
      chordKey: (fifths == null || tonality == null)
          ? defaults.chordKey
          : MusicKey(fifths: fifths, tonality: tonality),
      songAsset: await _prefs.getString('${_prefix}song'),
      hands:
          _byName(
            PlayHands.offered,
            await _prefs.getString('${_prefix}hands'),
          ) ??
          defaults.hands,
    );
  }

  Future<void> save(GameSettings settings) async {
    await _prefs.setString('${_prefix}mode', settings.mode.name);
    await _prefs.setIntList('${_prefix}octaves', settings.octaves.toList());
    await _prefs.setInt('${_prefix}duration', settings.durationSeconds);
    await _prefs.setBool('${_prefix}untimed', settings.untimed);
    await _prefs.setInt('${_prefix}chordKeyFifths', settings.chordKey.fifths);
    await _prefs.setString(
      '${_prefix}chordKeyTonality',
      settings.chordKey.tonality.name,
    );
    await _prefs.setString('${_prefix}hands', settings.hands.name);
    if (settings.songAsset case final song?) {
      await _prefs.setString('${_prefix}song', song);
    }
  }
}

T? _byName<T extends Enum>(List<T> values, String? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
