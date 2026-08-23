import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/core/providers.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/game_mode.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_event.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/game_controller.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/game_settings_controller.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/game_state.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/high_scores.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/note_source.dart';

import '../support/fakes.dart';

/// A round rig with no piano, no store and no wall clock.
class Rig {
  Rig({Map<String, String>? songs, Map<String, Object>? stored})
    : prefs = FakePreferencesService(stored),
      songAssets = FakeSongAssetService(
        songs ?? const {'a.song': 'title: Test\nRH: C4 D4 E4\n'},
      ) {
    container = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(clock),
        // Seeded, so every target the round deals is the same every run.
        entropyProvider.overrideWithValue(Random(1)),
        preferencesServiceProvider.overrideWithValue(prefs),
        songAssetServiceProvider.overrideWithValue(songAssets),
        midiDeviceServiceProvider.overrideWithValue(midi),
      ],
    );
    // Keep the round's state alive for the length of the test.
    container.listen(gameControllerProvider, (_, _) {});
    container.listen(noteSourceProvider, (_, _) {});
  }

  final clock = FakeClock();
  final midi = FakeMidiDeviceService();
  final FakePreferencesService prefs;
  final FakeSongAssetService songAssets;
  late final ProviderContainer container;

  GameState get state => container.read(gameControllerProvider);
  GameController get game => container.read(gameControllerProvider.notifier);

  /// Note events reach the grader through a broadcast stream, so each one
  /// lands a microtask later — exactly as it does on the device.
  Future<void> press(int note) async {
    container.read(noteSourceProvider.notifier).play(NotePressed(note, 80));
    await pump();
  }

  Future<void> release(int note) async {
    container.read(noteSourceProvider.notifier).play(NoteReleased(note));
    await pump();
  }

  /// Presses and releases every note of the current target.
  Future<void> answer() async {
    final targets = game.currentTargets();
    for (final note in targets) {
      await press(note);
    }
    for (final note in targets) {
      await release(note);
    }
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  void setMode(GameMode mode) =>
      container.read(gameSettingsControllerProvider.notifier).setMode(mode);
}

void main() {
  test('a round starts, scores and stops', () async {
    final rig = Rig();
    expect(rig.state.phase, GamePhase.idle);

    await rig.game.start();
    expect(rig.state.phase, GamePhase.playing);
    expect(rig.state.score, 0);

    await rig.answer();
    expect(rig.state.score, 1);
    expect(rig.state.verdict, Verdict.hit);

    rig.game.stop();
    expect(rig.state.phase, GamePhase.finished);
    expect(rig.state.score, 1);
  });

  test('a wrong key misses without scoring', () async {
    final rig = Rig();
    await rig.game.start();
    final target = rig.game.currentTargets().single;

    await rig.press(target == 60 ? 61 : 60);
    expect(rig.state.score, 0);
    expect(rig.state.misses, 1);
    expect(rig.state.verdict, Verdict.miss);
  });

  test('a scored key stays on the staff until it is let go of', () async {
    final rig = Rig();
    await rig.game.start();
    final target = rig.game.currentTargets().single;

    await rig.press(target);
    expect(rig.state.scored, {target});
    expect(rig.state.correct, contains(target));

    await rig.release(target);
    expect(rig.state.scored, isEmpty);
  });

  test('the clock runs the round out and records the score', () async {
    final rig = Rig();
    rig.container
        .read(gameSettingsControllerProvider.notifier)
        .setDuration(60);
    await rig.game.start();
    await rig.answer();
    expect(rig.state.remaining, const Duration(seconds: 60));

    rig.clock.advance(const Duration(seconds: 30));
    expect(rig.state.remaining, const Duration(seconds: 30));
    expect(rig.state.phase, GamePhase.playing);

    rig.clock.advance(const Duration(seconds: 30));
    expect(rig.state.phase, GamePhase.finished);
    expect(rig.state.remaining, Duration.zero);

    // The score landed in this settings combination's bucket.
    await Future<void>.delayed(Duration.zero);
    final bucket = rig.container
        .read(gameSettingsControllerProvider)
        .highScoreKey!;
    expect(rig.container.read(highScoresProvider.notifier).top(bucket), [1]);
  });

  test('an untimed round has no clock and records nothing', () async {
    final rig = Rig();
    rig.container.read(gameSettingsControllerProvider.notifier).setUntimed(true);
    await rig.game.start();
    await rig.answer();

    rig.clock.advance(const Duration(hours: 1));
    expect(rig.state.phase, GamePhase.playing);
    expect(rig.state.remaining, isNull);

    rig.game.stop();
    await Future<void>.delayed(Duration.zero);
    expect(rig.container.read(highScoresProvider), isEmpty);
  });

  test('a chords round needs the whole triad before it scores', () async {
    final rig = Rig()..setMode(GameMode.chords);
    await rig.game.start();
    final chord = rig.game.currentTargets();
    expect(chord, hasLength(3));

    await rig.press(chord[0]);
    await rig.press(chord[1]);
    expect(rig.state.score, 0);
    expect(rig.state.misses, 0); // partial is neither

    await rig.press(chord[2]);
    expect(rig.state.score, 1);
  });

  test('a song plays through and finishes on its own', () async {
    final rig = Rig()..setMode(GameMode.song);
    await rig.game.start();
    expect(rig.state.phase, GamePhase.playing);
    expect(rig.state.staff.columns, hasLength(3));

    var guard = 0;
    while (rig.state.isRunning && guard++ < 20) {
      await rig.answer();
    }
    expect(rig.state.phase, GamePhase.finished);
    expect(rig.state.score, 3);
  });

  test('a song that will not parse reports instead of hanging', () async {
    // v1 let this escape as an unhandled async error and left Play inert.
    final rig = Rig(songs: {'bad.song': 'title: Bad\nRH: [C4 X4]\n'})
      ..setMode(GameMode.song);
    await rig.game.start();

    expect(rig.state.phase, GamePhase.idle);
    expect(rig.state.error, isNotNull);
  });

  test('the idle staff follows the lowest key under your hand', () async {
    final rig = Rig();
    expect(rig.state.staff.columns, isEmpty);

    await rig.press(64);
    await rig.press(60);
    expect(rig.state.staff.columns.single.midiNotes, [60]);

    await rig.release(60);
    expect(rig.state.staff.columns.single.midiNotes, [64]);
  });

  test('hits and misses carry across rounds, the score does not', () async {
    final rig = Rig();
    await rig.game.start();
    await rig.answer();
    rig.game.stop();
    expect(rig.state.hits, 1);

    await rig.game.start();
    expect(rig.state.score, 0);
    expect(rig.state.hits, 1);
  });

  test('a second Play while one is in flight does not start twice', () async {
    final rig = Rig()..setMode(GameMode.song);
    final first = rig.game.start();
    final second = rig.game.start();
    await Future.wait([first, second]);
    expect(rig.state.phase, GamePhase.playing);
    expect(rig.state.cursor, 0);
  });
}
