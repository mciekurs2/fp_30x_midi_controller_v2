import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/data/repositories/high_score_repository.dart';
import 'package:fp_30x_midi_controller_v2/data/repositories/settings_repository.dart';
import 'package:fp_30x_midi_controller_v2/data/repositories/song_repository.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/game_mode.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/game_settings.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/music_key.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/song.dart';

import '../support/fakes.dart';

void main() {
  group('settings', () {
    test('round-trips every field', () async {
      final prefs = FakePreferencesService();
      final repository = SettingsRepository(prefs);
      final settings = GameSettings(
        mode: GameMode.keyChords,
        octaves: const {2, 6},
        durationSeconds: 90,
        untimed: true,
        chordKey: MusicKey.minor(3),
        songAsset: 'assets/songs/x.song',
        hands: PlayHands.left,
      );

      await repository.save(settings);
      final restored = await repository.load();

      expect(restored.mode, settings.mode);
      expect(restored.octaves, settings.octaves);
      expect(restored.durationSeconds, 90);
      expect(restored.untimed, isTrue);
      expect(restored.chordKey, settings.chordKey);
      expect(restored.songAsset, settings.songAsset);
      expect(restored.hands, PlayHands.left);
    });

    test('a fresh install loads the defaults', () async {
      final restored = await SettingsRepository(
        FakePreferencesService(),
      ).load();
      expect(restored.mode, GameSettings().mode);
      expect(restored.octaves, GameSettings().octaves);
      expect(restored.songAsset, isNull);
    });

    test('an unrecognised enum name falls back rather than throwing', () async {
      // What a store written by a build that spelled a mode differently holds.
      final prefs = FakePreferencesService({
        'gamesettings_mode': 'singleHand',
        'gamesettings_hands': 'sideways',
      });
      final restored = await SettingsRepository(prefs).load();
      expect(restored.mode, GameSettings().mode);
      expect(restored.hands, GameSettings().hands);
    });

    test('every offered hand survives a round trip', () async {
      // The store reads `hands` against PlayHands.offered, so a hand that is
      // offered must come back — and one that is not falls back instead, which
      // the unrecognised-name test above covers through the same path.
      for (final hand in PlayHands.offered) {
        final prefs = FakePreferencesService();
        final repository = SettingsRepository(prefs);
        await repository.save(GameSettings(hands: hand));
        expect((await repository.load()).hands, hand);
      }
    });

    test('a corrupt octave list does not take launch down', () async {
      // v1 called int.parse straight on this and threw a FormatException from
      // inside provider initialisation.
      final prefs = FakePreferencesService({
        'gamesettings_octaves': ['3', 'banana', '5'],
      });
      expect(await SettingsRepository(prefs).load(), isA<GameSettings>());
      expect((await SettingsRepository(prefs).load()).octaves, {3, 5});
    });

    test('an empty octave list falls back to the default pool', () async {
      final prefs = FakePreferencesService({
        'gamesettings_octaves': <String>[],
      });
      final restored = await SettingsRepository(prefs).load();
      expect(restored.octaves, GameSettings.defaultOctaves);
    });
  });

  group('high score buckets', () {
    test('each mode, duration and octave set gets its own', () {
      final a = GameSettings(mode: GameMode.chords, durationSeconds: 60);
      final b = GameSettings(mode: GameMode.singleNote, durationSeconds: 60);
      final c = GameSettings(mode: GameMode.chords, durationSeconds: 90);
      final d = GameSettings(mode: GameMode.chords, octaves: const {4});
      expect({
        a.highScoreKey,
        b.highScoreKey,
        c.highScoreKey,
        d.highScoreKey,
      }, hasLength(4));
    });

    test('only chords-in-key varies by key', () {
      String? keyFor(MusicKey key, GameMode mode) =>
          GameSettings(mode: mode, chordKey: key).highScoreKey;
      expect(
        keyFor(MusicKey.major(0), GameMode.keyChords),
        isNot(keyFor(MusicKey.major(7), GameMode.keyChords)),
      );
      expect(
        keyFor(MusicKey.major(0), GameMode.chords),
        keyFor(MusicKey.major(7), GameMode.chords),
      );
    });

    test('an untimed or self-paced round has no bucket', () {
      expect(GameSettings(untimed: true).highScoreKey, isNull);
      expect(GameSettings(mode: GameMode.song).highScoreKey, isNull);
    });

    test('the octave set orders consistently', () {
      expect(
        GameSettings(octaves: const {5, 3, 4}).highScoreKey,
        GameSettings(octaves: const {3, 4, 5}).highScoreKey,
      );
    });
  });

  group('high scores', () {
    test('keeps the top three, highest first', () async {
      final repository = HighScoreRepository(FakePreferencesService());
      var top = <int>[];
      for (final score in [10, 40, 22, 5, 31]) {
        top = await repository.record('bucket', score, top);
      }
      expect(top, [40, 31, 22]);
    });

    test('reloads what was written', () async {
      final prefs = FakePreferencesService();
      final repository = HighScoreRepository(prefs);
      await repository.record('a', 12, const []);
      await repository.record('b', 7, const []);
      expect(await repository.loadAll(), {
        'a': [12],
        'b': [7],
      });
    });

    test('a corrupt bucket loads empty rather than throwing', () async {
      final prefs = FakePreferencesService({
        'highscore_a': ['12', 'oops'],
      });
      expect(await HighScoreRepository(prefs).loadAll(), {
        'a': [12],
      });
    });
  });

  group('song library', () {
    const good = 'title: Good\nRH: C4 D4\n';
    const broken = 'title: Broken\nRH: [C4 X4]\n';

    test('lists what parses', () async {
      final repository = SongRepository(
        FakeSongAssetService({
          'a.song': good,
          'b.song': 'title: Also good\nRH: E4\n',
        }),
      );
      expect((await repository.library()).map((s) => s.title), [
        'Good',
        'Also good',
      ]);
    });

    test('a broken chart is left out, not thrown from', () async {
      // In v1 this escaped a fire-and-forget await as an unhandled error and
      // left Play doing nothing at all.
      final repository = SongRepository(
        FakeSongAssetService({'a.song': good, 'b.song': broken}),
      );
      final library = await repository.library();
      expect(library.map((s) => s.title), ['Good']);
      expect(repository.brokenSongs.keys, ['b.song']);
    });

    test('an unknown or absent choice falls back to the first', () async {
      final repository = SongRepository(
        FakeSongAssetService({'a.song': good}),
      );
      expect((await repository.load('gone.song'))?.title, 'Good');
      expect((await repository.load(null))?.title, 'Good');
    });

    test('nothing readable yields no song rather than an error', () async {
      final repository = SongRepository(
        FakeSongAssetService({'b.song': broken}),
      );
      expect(await repository.load(null), isNull);
    });
  });
}
