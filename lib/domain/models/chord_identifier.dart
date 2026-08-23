import 'chord.dart';
import 'music_key.dart';
import 'pitch.dart';

/// A chord recognised from whatever keys are down, as opposed to [Chord], which
/// the app deals out. Only pitch classes matter, so doublings and wide voicings
/// name the same chord; [bass] is kept for the slash name.
class PlayedChord {
  const PlayedChord({
    required this.root,
    required this.bass,
    required this.quality,
  });

  /// Pitch classes, not MIDI notes.
  final int root;
  final int bass;
  final ChordQuality quality;

  MusicKey get key => quality.spellAs == Tonality.major
      ? MusicKey.major(root)
      : MusicKey.minor(root);

  bool get inverted => bass != root;

  /// `Cmaj7`, `Gbm7b5`, or `C/E` when the bass is not the root.
  String get name {
    final chord = '${key.tonicName}${quality.suffix}';
    return inverted ? '$chord/$_bassName' : chord;
  }

  /// Spelled to match the root: a flat chord takes flat names, a sharp chord
  /// sharp ones. C major and A minor sign nothing, so those fall back to the
  /// conventional spelling rather than forcing A# on a C7's seventh.
  String get _bassName => switch (key.accidental) {
    Accidental.flat => _flatNames[bass],
    Accidental.sharp => _sharpNames[bass],
    _ => pitchClassName(bass),
  };
}

const _sharpNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
];
const _flatNames = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
];

/// Names the chord [midiNotes] spell, or `null` for fewer than three distinct
/// pitches or a shape outside [ChordQuality].
///
/// Several roots can fit one set — C-D-G is both Csus2 and Gsus4, a dim7 fits
/// all four of its notes — so matches are ranked by whether the root is in the
/// bass first, then by how common the quality is (its declaration order).
PlayedChord? identifyChord(Iterable<int> midiNotes) {
  final notes = midiNotes.toList()..sort();
  if (notes.isEmpty) return null;

  final bass = mod(notes.first, 12);
  final pitchClasses = {for (final note in notes) mod(note, 12)};
  if (pitchClasses.length < 3) return null;

  PlayedChord? best;
  var bestRank = 0;
  for (final root in pitchClasses) {
    final intervals = {for (final pc in pitchClasses) mod(pc - root, 12)};
    for (final quality in ChordQuality.values) {
      if (quality.intervals.length != intervals.length ||
          !intervals.containsAll(quality.intervals)) {
        continue;
      }
      final rank = (root == bass ? 0 : 100) + quality.index;
      if (best == null || rank < bestRank) {
        best = PlayedChord(root: root, bass: bass, quality: quality);
        bestRank = rank;
      }
      break;
    }
  }
  return best;
}

/// What the readout shows: one key by name and octave (`Eb3`), a recognised
/// chord (`Cmaj7`, `C/E`), or — when nothing in the catalogue fits — the held
/// keys listed rather than a guess. `null` when nothing is down.
String? playedName(Iterable<int> midiNotes) {
  final notes = midiNotes.toList()..sort();
  if (notes.isEmpty) return null;

  final pitchClasses = {for (final note in notes) mod(note, 12)};
  if (pitchClasses.length == 1) return noteName(notes.first);

  return identifyChord(notes)?.name ?? notes.map(noteName).join(' ');
}
