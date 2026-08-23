import 'dart:math';

import 'music_key.dart';
import 'pitch.dart';

/// The chord shapes the app can name. [Chord] targets in the chords mode draw
/// only from [gameQualities]; the rest exist for recognising what is played.
///
/// Declaration order is the tie-break for ambiguous pitch-class sets (see
/// `chord_identifier.dart`), so it runs roughly from commonest to rarest.
enum ChordQuality {
  major([0, 4, 7], '', Tonality.major),
  minor([0, 3, 7], 'm', Tonality.minor),
  dominant7([0, 4, 7, 10], '7', Tonality.major),
  major7([0, 4, 7, 11], 'maj7', Tonality.major),
  minor7([0, 3, 7, 10], 'm7', Tonality.minor),
  diminished([0, 3, 6], 'dim', Tonality.minor),
  halfDiminished([0, 3, 6, 10], 'm7b5', Tonality.minor),
  diminished7([0, 3, 6, 9], 'dim7', Tonality.minor),
  augmented([0, 4, 8], 'aug', Tonality.major),
  sus4([0, 5, 7], 'sus4', Tonality.major),
  sus2([0, 2, 7], 'sus2', Tonality.major),
  dominant7sus4([0, 5, 7, 10], '7sus4', Tonality.major),
  sixth([0, 4, 7, 9], '6', Tonality.major),
  minorSixth([0, 3, 7, 9], 'm6', Tonality.minor),
  minorMajor7([0, 3, 7, 11], 'mMaj7', Tonality.minor);

  const ChordQuality(this.intervals, this.suffix, this.spellAs);

  /// Semitones above the root, root position.
  final List<int> intervals;

  /// Appended to the root letter for the chord's name.
  final String suffix;

  /// Which key spells the root, so a minor-third chord reads C#m and a
  /// major-third one Gb rather than mixing signs.
  final Tonality spellAs;

  /// What the chords mode deals out: root-position triads only, by design.
  static const gameQualities = [major, minor];
}

/// A root-position chord the player must hold. The [root] is a concrete MIDI
/// note, so [notes] is a specific voicing, not just pitch classes.
class Chord {
  const Chord(this.root, this.quality);

  final int root;
  final ChordQuality quality;

  List<int> get notes => [for (final i in quality.intervals) root + i];

  /// The key this chord belongs to, which fixes its spelling (all sharps or all
  /// flats, never mixed) and its signature.
  MusicKey get key => quality.spellAs == Tonality.major
      ? MusicKey.major(mod(root, 12))
      : MusicKey.minor(mod(root, 12));

  /// Spelled from the key, so the letter matches the notes (Gb, not F#).
  String get name => '${key.tonicName}${quality.suffix}';

  /// The name as [key] writes it: the ii of F# major reads A#m, where [name]
  /// would say Bbm — a letter away from the line its notehead is sitting on.
  String nameIn(MusicKey key) =>
      '${key.spell(mod(root, 12)) ?? this.key.tonicName}${quality.suffix}';

  @override
  bool operator ==(Object other) =>
      other is Chord && other.root == root && other.quality == quality;

  @override
  int get hashCode => Object.hash(root, quality);

  @override
  String toString() => '$name (${notes.join(' ')})';
}

/// A random chord rooted in [octaves], drawn from [from] — the two game triads
/// unless a caller asks for more. `null` if the pool is empty.
Chord? randomChord(
  Set<int> octaves,
  Random random, {
  Chord? avoiding,
  List<ChordQuality> from = ChordQuality.gameQualities,
}) {
  final pool = [
    for (final root in midiPool(octaves))
      for (final quality in from) Chord(root, quality),
  ];
  return pickFrom(pool, random, avoiding: avoiding);
}

/// A random triad diatonic to [key], rooted in [octaves]. The root is a scale
/// degree — so a written C in D major *is* C# — and every note falls in the
/// key, which is what lets the staff draw the chord bare under its signature.
///
/// Neither quality fits on the 7th degree of a major key (its triad is
/// diminished), so the filter alone leaves the six shapes the mode deals.
Chord? randomChordInKey(
  Set<int> octaves,
  MusicKey key,
  Random random, {
  Chord? avoiding,
}) {
  final scale = key.pitchClasses;
  final pool = [
    for (final root in midiPool(octaves))
      if (scale.contains(mod(root, 12)))
        for (final quality in ChordQuality.gameQualities)
          Chord(root, quality),
  ].where((chord) => chord.notes.every((n) => scale.contains(mod(n, 12))));

  return pickFrom(pool.toList(), random, avoiding: avoiding);
}
