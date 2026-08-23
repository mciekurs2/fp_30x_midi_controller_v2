import 'dart:math';

import '../../notation/model/score.dart';
import '../models/note_value.dart';
import '../models/pitch.dart';
import 'exercise.dart';

/// One note at a time: press exactly the key on the staff. Anything else misses.
class SingleNoteExercise extends Exercise {
  SingleNoteExercise({required this.octaves, required Random random, int? first})
    : _random = random,
      _target = first ?? randomNote(octaves, random)!;

  final Set<int> octaves;
  final Random _random;
  int _target;

  int get target => _target;

  @override
  late Score score = _scoreFor(_target);

  @override
  Set<int> get required => {_target};

  /// One live attempt: the lowest key not already spent. A key resting on the
  /// staff from the last answer should not read as a second guess.
  @override
  Set<int> attemptFrom(Set<int> unspent) =>
      unspent.isEmpty ? const {} : {unspent.reduce(min)};

  @override
  GradeResult grade({required int pressed, required Set<int> held}) {
    if (pressed != _target) return const Miss();
    final scored = _target;
    _target = randomNote(octaves, _random, avoiding: scored) ?? scored;
    score = _scoreFor(_target);
    return Hit(scored: {scored});
  }

  static Score _scoreFor(int note) => Score.chord(
    [note],
    value: NoteValue.quaver,
    label: noteName(note),
  );
}
