import 'dart:math';

import '../../notation/model/score.dart';
import '../../notation/model/spelling.dart';
import '../models/chord.dart';
import '../models/music_key.dart';
import '../models/note_value.dart';
import 'exercise.dart';

/// Where a chords round draws its targets from, and how it writes them.
///
/// The plain chords mode roams the whole octave pool and spells each chord from
/// its own key; the in-key mode draws only chords diatonic to one key, writes
/// its signature at the head of the staff, and leaves the noteheads bare.
sealed class ChordSource {
  const ChordSource();

  Chord? next(Set<int> octaves, Random random, {Chord? avoiding});

  Spelling spellingFor(Chord chord);

  String labelFor(Chord chord);

  MusicKey? get signatureKey => null;
}

/// Any major or minor triad, spelled consistently from its own key: all sharps
/// for a sharp chord, all flats for a flat one, never mixed. Every accidental
/// is drawn beside its notehead.
class AnyChordSource extends ChordSource {
  const AnyChordSource();

  @override
  Chord? next(Set<int> octaves, Random random, {Chord? avoiding}) =>
      randomChord(octaves, random, avoiding: avoiding);

  @override
  Spelling spellingFor(Chord chord) => Spelling.matching(chord.key);

  @override
  String labelFor(Chord chord) => chord.name;
}

/// Triads diatonic to one key. A note in the key draws bare, and the signature
/// at the start of the staff is the only thing that says so.
class KeyChordSource extends ChordSource {
  const KeyChordSource(this.key);

  final MusicKey key;

  @override
  Chord? next(Set<int> octaves, Random random, {Chord? avoiding}) =>
      randomChordInKey(octaves, key, random, avoiding: avoiding);

  @override
  Spelling spellingFor(Chord chord) => Spelling.forKey(key);

  /// Named by the *chosen* key, not the chord's own, so the letter matches the
  /// line its notehead sits on — A#m in F# major, never Bbm.
  @override
  String labelFor(Chord chord) => chord.nameIn(key);

  @override
  MusicKey? get signatureKey => key;
}

/// A triad at a time, graded leniently: a hit the moment every note is held, in
/// any order; a key outside the chord misses but leaves progress intact; a
/// correct-but-partial press simply waits.
class ChordExercise extends Exercise {
  ChordExercise({
    required this.octaves,
    required this.source,
    required Random random,
    Chord? first,
  }) : _random = random,
       _chord = first ?? source.next(octaves, random)!;

  final Set<int> octaves;
  final ChordSource source;
  final Random _random;
  Chord _chord;

  Chord get chord => _chord;

  @override
  late Score score = _scoreFor(_chord);

  @override
  Set<int> get required => _chord.notes.toSet();

  @override
  GradeResult grade({required int pressed, required Set<int> held}) {
    final notes = required;
    if (held.containsAll(notes)) {
      final answered = _chord;
      _chord = source.next(octaves, _random, avoiding: answered) ?? answered;
      score = _scoreFor(_chord);
      return Hit(scored: notes);
    }
    return notes.contains(pressed) ? const Pending() : const Miss();
  }

  Score _scoreFor(Chord chord) => Score.chord(
    chord.notes,
    value: NoteValue.semibreve,
    spelling: source.spellingFor(chord),
    signatureKey: source.signatureKey,
    label: source.labelFor(chord),
  );
}
