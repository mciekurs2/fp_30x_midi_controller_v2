import '../../domain/models/music_key.dart';
import '../../domain/models/note_value.dart';
import '../../domain/models/pitch.dart';
import '../../domain/models/song.dart';
import 'clef.dart';
import 'spelling.dart';
import 'staff_placement.dart';

/// One stave of a system.
class Stave {
  const Stave(this.clef);

  final Clef clef;

  @override
  bool operator ==(Object other) => other is Stave && other.clef == clef;

  @override
  int get hashCode => clef.hashCode;
}

/// A note in a score: the key to press, plus — when the source fixes it, as a
/// `.song` file does — exactly how it is written. Left unspelled, the [Score]'s
/// [Spelling] decides.
class ScoreNote {
  const ScoreNote(this.midi) : letter = null, octave = null, drawn = null;

  const ScoreNote.spelled(
    this.midi, {
    required this.letter,
    required this.octave,
    this.drawn,
  });

  ScoreNote.fromSong(SongNote note)
    : midi = note.midi,
      letter = note.letter,
      octave = note.octave,
      drawn = note.drawn;

  final int midi;

  /// 0=C … 6=B, or `null` to derive the letter from the spelling.
  final int? letter;

  /// Scientific octave, C4 = middle C.
  final int? octave;

  /// The accidental to draw. `null` on a spelled note means the signature has
  /// already said it.
  final Accidental? drawn;

  bool get isSpelled => letter != null && octave != null;

  /// Where this note sits on [clef], written its own way where it has one.
  StaffPlacement placeOn(Clef clef, Spelling spelling) => isSpelled
      ? StaffPlacement.spelled(letter!, octave!, drawn, clef)
      : StaffPlacement.inClef(midi, clef, spelling);

  @override
  bool operator ==(Object other) =>
      other is ScoreNote &&
      other.midi == midi &&
      other.letter == letter &&
      other.octave == octave &&
      other.drawn == drawn;

  @override
  int get hashCode => Object.hash(midi, letter, octave, drawn);
}

/// What one stave does at one onset: a strike of [notes], or a rest when they
/// are empty.
class ScoreVoice {
  const ScoreVoice({
    required this.notes,
    this.value = NoteValue.crotchet,
    this.dotted = false,
    this.label,
    this.caption,
  });

  ScoreVoice.fromSong(SongEvent event)
    : notes = [for (final note in event.notes) ScoreNote.fromSong(note)],
      value = event.value,
      dotted = event.dotted,
      label = event.label,
      caption = event.chordName;

  final List<ScoreNote> notes;
  final NoteValue value;
  final bool dotted;

  /// The keys to press, named — drawn under the stave.
  final String? label;

  /// What those keys spell as a chord, drawn under [label].
  final String? caption;

  bool get isRest => notes.isEmpty;

  List<int> get midiNotes => [for (final note in notes) note.midi];
}

/// A vertical slice of the system: what each stave plays at one onset.
class ScoreColumn {
  const ScoreColumn({required this.voices, this.startsBar = false});

  /// One entry per stave, indexed as [Score.staves]. `null` where that stave is
  /// silent — no notehead and no rest.
  final List<ScoreVoice?> voices;
  final bool startsBar;

  Iterable<ScoreNote> get notes => [
    for (final voice in voices) ...?voice?.notes,
  ];

  List<int> get midiNotes => [for (final note in notes) note.midi];
}

/// Everything the staff draws, produced by whatever exercise is being played.
/// The notation layer knows nothing beyond this — no targets, no grading.
class Score {
  Score({
    required this.staves,
    required this.columns,
    this.signatureKey,
    this.spelling = Spelling.conventional,
    this.barlines = true,
  });

  /// An empty system: staff lines and a clef, nothing on them.
  Score.empty({Clef clef = Clef.treble})
    : staves = [Stave(clef)],
      columns = const [],
      signatureKey = null,
      spelling = Spelling.conventional,
      barlines = true;

  /// One note or one chord on a single stave, its clef chosen from the lowest
  /// note so a chord's notes share one.
  factory Score.chord(
    List<int> notes, {
    NoteValue value = NoteValue.crotchet,
    Spelling spelling = Spelling.conventional,
    MusicKey? signatureKey,
    String? label,
    String? caption,
  }) {
    if (notes.isEmpty) return Score.empty();
    final sorted = [...notes]..sort();
    return Score(
      staves: [Stave(Clef.forNote(sorted.first))],
      columns: [
        ScoreColumn(
          voices: [
            ScoreVoice(
              notes: [for (final note in sorted) ScoreNote(note)],
              value: value,
              label: label,
              caption: caption,
            ),
          ],
        ),
      ],
      spelling: spelling,
      signatureKey: signatureKey,
    );
  }

  /// A piece of sheet music. [hands] decides which staves are drawn: a one-hand
  /// round shows that hand alone, centred, rather than an empty partner stave.
  factory Score.song(Song song, PlayHands hands) {
    final drawn = [
      for (final hand in Hand.values)
        if (song.hands.contains(hand) && hands.plays(hand)) hand,
    ];
    final staves = drawn.isEmpty ? song.hands.toList() : drawn;
    if (staves.isEmpty) return Score.empty();

    return Score(
      staves: [for (final hand in staves) Stave(Clef.forHand(hand))],
      columns: [
        for (final column in song.columns)
          ScoreColumn(
            voices: [
              for (final hand in staves)
                if (column.eventFor(hand) case final event?)
                  ScoreVoice.fromSong(event)
                else
                  null,
            ],
            startsBar: column.startsBar,
          ),
      ],
      signatureKey: song.key,
      spelling: song.key == null
          ? Spelling.conventional
          : Spelling.forKey(song.key!),
      barlines: song.barlines,
    );
  }

  final List<Stave> staves;
  final List<ScoreColumn> columns;

  /// Drawn at the start of the system when set, and then excusing the key's own
  /// notes from carrying accidentals of their own.
  final MusicKey? signatureKey;
  final Spelling spelling;
  final bool barlines;

  bool get isEmpty => columns.isEmpty;

  /// Whether any column captions a chord — decided score-wide so a chordless
  /// column does not close the gap and jog the rows as the cursor advances.
  late final bool hasCaptions = columns.any(
    (column) => column.voices.any((voice) => voice?.caption != null),
  );

  /// The signature actually drawn: a key with no accidentals draws nothing.
  MusicKey? get drawnSignature =>
      signatureKey?.accidental == null ? null : signatureKey;
}
