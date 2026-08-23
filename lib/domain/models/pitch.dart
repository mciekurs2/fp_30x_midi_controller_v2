import 'dart:math';

/// Floored modulo; Dart's `%` already floors for a positive modulus, but this
/// keeps the intent explicit when walking backwards round a circle of 7 or 12.
int mod(int value, int modulus) {
  final remainder = value % modulus;
  return remainder < 0 ? remainder + modulus : remainder;
}

/// A written accidental. Double accidentals are unsupported throughout.
enum Accidental { sharp, flat, natural }

/// Note letters in scale order, indexed 0=C … 6=B.
const letterNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

/// The pitch class each letter carries with no accidental, indexed as
/// [letterNames].
const naturalPitches = [0, 2, 4, 5, 7, 9, 11];

/// The MIDI notes in [octaves], where octave *n* begins at `(n + 1) * 12`.
List<int> midiPool(Set<int> octaves) => [
  for (final octave in octaves)
    for (var semitone = 0; semitone < 12; semitone++)
      semitone + (octave + 1) * 12,
];

/// A random element of [pool], skipping [avoiding] unless it is the only
/// choice. `null` when the pool is empty.
T? pickFrom<T>(List<T> pool, Random random, {T? avoiding}) {
  if (pool.isEmpty) return null;
  final fresh = pool.where((item) => item != avoiding).toList();
  final from = fresh.isNotEmpty ? fresh : pool;
  return from[random.nextInt(from.length)];
}

/// A random MIDI note from [octaves], skipping [avoiding] where it can.
int? randomNote(Set<int> octaves, Random random, {int? avoiding}) =>
    pickFrom(midiPool(octaves), random, avoiding: avoiding);

int octaveOf(int midiNote) => midiNote ~/ 12 - 1;

/// Conventional spelling for isolated black keys (C♯, E♭, F♯, A♭, B♭).
const _noteNames = [
  'C',
  'C#',
  'D',
  'Eb',
  'E',
  'F',
  'F#',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

String pitchClassName(int pitchClass) => _noteNames[mod(pitchClass, 12)];

String noteName(int midiNote) =>
    '${pitchClassName(midiNote)}${octaveOf(midiNote)}';
