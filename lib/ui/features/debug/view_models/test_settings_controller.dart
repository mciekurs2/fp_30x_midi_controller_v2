import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers.dart';
import '../../../../domain/models/chord.dart';
import '../../../../domain/models/pitch.dart';

part 'test_settings_controller.g.dart';

/// What "Play note" presses: a random pick, the round's target, 50/50, or a
/// random chord — the last ignores targets, so the chord readout can be
/// exercised without a piano.
enum TestNoteSource {
  random('Random'),
  target('Target'),
  mixed('50/50'),
  chord('Chord');

  const TestNoteSource(this.title);

  final String title;
}

class TestSettings {
  const TestSettings({
    this.noteSource = TestNoteSource.random,
    this.octaves = const {4, 5},
  });

  final TestNoteSource noteSource;

  /// A set, so octaves can be drilled without their neighbours.
  final Set<int> octaves;

  TestSettings copyWith({TestNoteSource? noteSource, Set<int>? octaves}) =>
      TestSettings(
        noteSource: noteSource ?? this.noteSource,
        octaves: octaves ?? this.octaves,
      );
}

/// Knobs for the debug controls, and the note picking they drive.
@Riverpod(keepAlive: true)
class TestSettingsController extends _$TestSettingsController {
  int? _lastNote;
  Chord? _lastChord;

  @override
  TestSettings build() => const TestSettings();

  void setSource(TestNoteSource source) =>
      state = state.copyWith(noteSource: source);

  /// The pool must never empty, so clearing the last octave is ignored.
  void setOctaves(Set<int> octaves) {
    if (octaves.isEmpty) return;
    state = state.copyWith(octaves: octaves);
  }

  /// The notes a "Play note" tap presses: a whole chord under
  /// [TestNoteSource.chord], one random note when nothing is being asked for,
  /// else the source decides whether each target is hit or missed.
  List<int> nextNotes(List<int> targets) {
    if (state.noteSource == TestNoteSource.chord) return _nextChord();
    if (targets.isEmpty) return [?_nextRandom()];
    return [
      for (final target in targets) ?(_aim(target) ?? _miss(target)),
    ];
  }

  /// The note that hits [target], or `null` to miss instead.
  int? _aim(int target) => switch (state.noteSource) {
    // `chord` short-circuits before this, and neither ever aims.
    TestNoteSource.random || TestNoteSource.chord => null,
    TestNoteSource.target => target,
    TestNoteSource.mixed => _random.nextBool() ? target : null,
  };

  /// A wrong note from the target's own octave, so a miss lands near it.
  int? _miss(int target) =>
      randomNote({octaveOf(target)}, _random, avoiding: target);

  /// Any shape in the catalogue, not just the two the chords mode deals, so
  /// the readout's naming can be driven without hardware. Root position only —
  /// slash names still need real hands.
  List<int> _nextChord() {
    _lastChord = randomChord(
      state.octaves,
      _random,
      avoiding: _lastChord,
      from: ChordQuality.values,
    );
    return _lastChord?.notes ?? const [];
  }

  /// Never repeats the previous note, so a second tap always reads as one.
  int? _nextRandom() =>
      _lastNote = randomNote(state.octaves, _random, avoiding: _lastNote);

  Random get _random => ref.read(entropyProvider);
}
