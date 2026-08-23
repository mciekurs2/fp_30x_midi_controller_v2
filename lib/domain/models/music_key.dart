import 'pitch.dart';

enum Tonality {
  major('Major', [0, 2, 4, 5, 7, 9, 11], (letter: 0, pitch: 0)),
  minor('Minor', [0, 2, 3, 5, 7, 8, 10], (letter: -2, pitch: -3));

  const Tonality(this.title, this.steps, this.tonicOffset);

  final String title;

  /// The scale in semitones from its tonic.
  final List<int> steps;

  /// Where the tonic sits against the major of the same signature: a minor key
  /// is its relative major begun two letters and three semitones lower.
  final ({int letter, int pitch}) tonicOffset;
}

/// A major or minor key, identified by its place on the circle of fifths.
///
/// Which notes belong to it, their letters and the signature all follow from
/// [fifths]. Minor keys are natural minor — the signature and nothing else.
class MusicKey {
  const MusicKey({required this.fifths, required this.tonality});

  /// Signed: sharps above zero, flats below.
  final int fifths;
  final Tonality tonality;

  static const cMajor = MusicKey(fifths: 0, tonality: Tonality.major);

  /// Circle-of-fifths position for each major tonic pitch class, choosing the
  /// spelling with ≤6 accidentals (the F♯/G♭ tritone tie resolves to flats).
  static const _majorFifths = [0, -5, 2, -3, 4, -1, -6, 1, -4, 3, -2, 5];

  factory MusicKey.major(int tonicPitchClass) =>
      MusicKey(fifths: _majorFifths[tonicPitchClass], tonality: Tonality.major);

  /// A minor key shares its relative major's signature (three semitones up).
  factory MusicKey.minor(int tonicPitchClass) => MusicKey(
    fifths: _majorFifths[mod(tonicPitchClass + 3, 12)],
    tonality: Tonality.minor,
  );

  /// The tonic as a pitch class, the inverse of [MusicKey.major]/[MusicKey.minor].
  int get tonicPitchClass => _tonicPitch;

  Accidental? get accidental => switch (fifths) {
    > 0 => Accidental.sharp,
    < 0 => Accidental.flat,
    _ => null,
  };

  int get accidentalCount => fifths.abs();

  Set<int> get pitchClasses => {
    for (final step in tonality.steps) mod(_tonicPitch + step, 12),
  };

  bool contains(int pitchClass) => pitchClasses.contains(pitchClass);

  /// The letter a pitch is written on in this key, or `null` for a pitch
  /// outside it — which is what tells a wrong note from a right one at the
  /// drawing stage.
  int? letterIndex(int pitchClass) {
    for (var degree = 0; degree < tonality.steps.length; degree++) {
      if (mod(_tonicPitch + tonality.steps[degree], 12) == pitchClass) {
        return mod(_tonicLetter + degree, 7);
      }
    }
    return null;
  }

  /// Semitone alteration the signature applies to [letter] (0=C … 6=B): +1 for
  /// a sharp letter, -1 for a flat, 0 for a natural. Every letter appears
  /// exactly once in a diatonic scale, so a key-implicit note takes this
  /// without writing an accidental.
  int alterationForLetter(int letter) {
    for (var degree = 0; degree < tonality.steps.length; degree++) {
      if (mod(_tonicLetter + degree, 7) == letter) {
        final pitch = mod(_tonicPitch + tonality.steps[degree], 12);
        return mod(pitch - naturalPitches[letter] + 6, 12) - 6;
      }
    }
    return 0;
  }

  /// How this key writes [pitchClass] — `C#` in D major, `Bb` in F major, and
  /// `null` for a pitch outside the scale, which has no key-given letter.
  String? spell(int pitchClass) {
    final letter = letterIndex(pitchClass);
    if (letter == null) return null;
    final sign = switch (alterationForLetter(letter)) {
      > 0 => '#',
      < 0 => 'b',
      _ => '',
    };
    return '${letterNames[letter]}$sign';
  }

  /// The tonic's letter + sign, e.g. `C`, `F#`, `Eb` (ASCII, matching the app).
  String get tonicName => spell(_tonicPitch)!;

  String get name => '$tonicName ${tonality.title.toLowerCase()}';

  /// The letter its tonic is written on, 0=C … 6=B.
  int get tonicLetter => _tonicLetter;

  int get _tonicLetter => mod(fifths * 4 + tonality.tonicOffset.letter, 7);
  int get _tonicPitch => mod(fifths * 7 + tonality.tonicOffset.pitch, 12);

  @override
  bool operator ==(Object other) =>
      other is MusicKey && other.fifths == fifths && other.tonality == tonality;

  @override
  int get hashCode => Object.hash(fifths, tonality);

  @override
  String toString() => name;
}
