import '../../domain/models/music_key.dart';
import '../../domain/models/pitch.dart';
import 'clef.dart';
import 'spelling.dart';

/// Where a note lands on the staff, in diatonic steps from the middle line.
class StaffPlacement {
  const StaffPlacement._({
    required this.clef,
    required this.steps,
    required this.ledgerSteps,
    required this.accidental,
  });

  /// Positive is up the staff. Lines sit on even steps, spaces on odd.
  final Clef clef;
  final int steps;
  final List<int> ledgerSteps;
  final Accidental? accidental;

  /// Picks the clef from the note, then places it. Used for a lone note.
  factory StaffPlacement(
    int midiNote, [
    Spelling spelling = Spelling.conventional,
  ]) => StaffPlacement.inClef(midiNote, Clef.forNote(midiNote), spelling);

  /// Places a note in a caller-chosen clef, so a chord's notes can share one.
  factory StaffPlacement.inClef(
    int midiNote,
    Clef clef, [
    Spelling spelling = Spelling.conventional,
  ]) {
    // The middle line is a fixed physical line, so its reference is its natural
    // letter — a key that would respell it (B→C♭ in G♭ major) must not move it.
    final steps =
        _diatonicIndex(midiNote, spelling) -
        _diatonicIndex(clef.middleLineNote, Spelling.conventional);

    return StaffPlacement._(
      clef: clef,
      steps: steps,
      ledgerSteps: _ledgers(steps),
      accidental: _accidental(midiNote, spelling),
    );
  }

  /// Places a note by its explicit written spelling — [letter] (0=C … 6=B),
  /// scientific [octave] (C4 = middle C), and the accidental to draw (`null`
  /// when the key signature already covers it). Used for song notation, where
  /// the spelling comes straight from the file rather than a MIDI heuristic.
  factory StaffPlacement.spelled(
    int letter,
    int octave,
    Accidental? drawn,
    Clef clef,
  ) {
    final steps =
        (octave + 1) * 7 +
        letter -
        _diatonicIndex(clef.middleLineNote, Spelling.conventional);
    return StaffPlacement._(
      clef: clef,
      steps: steps,
      ledgerSteps: _ledgers(steps),
      accidental: drawn,
    );
  }

  /// Ledger-line steps a note at [steps] needs, above or below the staff.
  static List<int> _ledgers(int steps) {
    final ledgerSteps = <int>[];
    if (steps >= 5) {
      for (var step = 6; step <= steps; step += 2) {
        ledgerSteps.add(step);
      }
    } else if (steps <= -5) {
      for (var step = -6; step >= steps; step -= 2) {
        ledgerSteps.add(step);
      }
    }
    return ledgerSteps;
  }

  /// Letter for each pitch class: a sharp takes the letter below, a flat above.
  static const _sharpSteps = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
  static const _flatSteps = [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6];

  /// Conventional spelling of isolated black keys; keys are the black classes.
  static const _conventionalAccidentals = <int, Accidental>{
    1: Accidental.sharp, // C#
    3: Accidental.flat, // Eb
    6: Accidental.sharp, // F#
    8: Accidental.flat, // Ab
    10: Accidental.flat, // Bb
  };

  /// Under a key, the scale's own notes need nothing — the signature has said
  /// it. A pitch outside the scale draws a natural when the key alters that
  /// letter, else the accidental the signature is built from, so a wrong note's
  /// spelling follows the key. Otherwise `sharps`/`flats` force one.
  static Accidental? _accidental(int midiNote, Spelling spelling) {
    final pitchClass = mod(midiNote, 12);
    if (spelling.kind != SpellingKind.key) {
      final conventional = _conventionalAccidentals[pitchClass];
      if (conventional == null) return null;
      return switch (spelling.kind) {
        SpellingKind.sharps => Accidental.sharp,
        SpellingKind.flats => Accidental.flat,
        _ => conventional,
      };
    }
    final key = spelling.key!;
    if (key.contains(pitchClass)) return null;
    final conventional = _conventionalAccidentals[pitchClass];
    if (conventional == null) return Accidental.natural;
    return key.accidental ?? conventional;
  }

  /// A key spells its own notes by their scale letters; everything else derives
  /// the letter from the accidental so the two cannot disagree.
  static int _letterIndex(int midiNote, Spelling spelling) {
    final pitchClass = mod(midiNote, 12);
    if (spelling.kind == SpellingKind.key) {
      final letter = spelling.key!.letterIndex(pitchClass);
      if (letter != null) return letter;
    }
    final table = _accidental(midiNote, spelling) == Accidental.flat
        ? _flatSteps
        : _sharpSteps;
    return table[pitchClass];
  }

  static int _diatonicIndex(int midiNote, Spelling spelling) {
    final letter = _letterIndex(midiNote, spelling);
    return (_octave(midiNote, letter) + 1) * 7 + letter;
  }

  /// Semitones from the letter's natural: 1 sharp, -1 flat, 0 as it lies.
  static int _alteration(int midiNote, int letter) =>
      mod(mod(midiNote, 12) - naturalPitches[letter] + 6, 12) - 6;

  /// The octave a note is *written* in, not always the one it sounds in.
  static int _octave(int midiNote, int letter) {
    final raw = mod(midiNote, 12) - naturalPitches[letter];
    return midiNote ~/ 12 - 1 + (raw - _alteration(midiNote, letter)) ~/ 12;
  }
}

/// Staff positions a key signature occupies, in writing order: F C G D A E B
/// for sharps, reversed for flats. The bass row is the treble's two steps down.
List<int> signatureSteps(MusicKey key, Clef clef) {
  final accidental = key.accidental;
  if (accidental == null) return const [];
  final row = accidental == Accidental.sharp ? _sharpRow : _flatRow;
  return [
    for (final step in row.take(key.accidentalCount)) step + clef.signatureDrop,
  ];
}

const _sharpRow = [4, 1, 5, 2, -1, 3, 0];
const _flatRow = [0, 3, -1, 2, -2, 1, -3];
