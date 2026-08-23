import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/high_score_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/song_repository.dart';
import '../data/services/midi_device_service.dart';
import '../data/services/preferences_service.dart';
import '../data/services/song_asset_service.dart';
import 'clock.dart';

part 'providers.g.dart';

/// The seams the app is built on. Every one is overridable in a test, which is
/// what lets rounds be played, timed and scored without hardware or a store.

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
Random entropy(Ref ref) => Random();

@Riverpod(keepAlive: true)
PreferencesService preferencesService(Ref ref) => SharedPreferencesService();

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(preferencesServiceProvider));

@Riverpod(keepAlive: true)
HighScoreRepository highScoreRepository(Ref ref) =>
    HighScoreRepository(ref.watch(preferencesServiceProvider));

@Riverpod(keepAlive: true)
SongAssetService songAssetService(Ref ref) => const BundledSongAssetService();

@Riverpod(keepAlive: true)
SongRepository songRepository(Ref ref) =>
    SongRepository(ref.watch(songAssetServiceProvider));

@Riverpod(keepAlive: true)
MidiDeviceService midiDeviceService(Ref ref) {
  final service = BleMidiDeviceService();
  ref.onDispose(service.dispose);
  return service;
}
