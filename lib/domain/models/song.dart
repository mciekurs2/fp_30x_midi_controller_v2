import 'chord_identifier.dart';
import 'music_key.dart';
import 'note_value.dart';
import 'pitch.dart';

/// A hand of a song. Which staff it is written on is the notation layer's call.
enum Hand { right, left }

/// Which hands a round asks the player to cover.
enum PlayHands {
  right('Right'),
  left('Left'),
  both('Both');

  const PlayHands(this.title);

  final String title;

  /// The hands a round can be set to.
  ///
  /// Kept separate from [values] so a hand can be withheld from the settings
  /// sheet and from anything read back out of the store at once — an install
  /// that chose a hand no longer offered falls back to the default rather than
  /// keeping it.
  static const offered = [right, left, both];

  bool get playsRight => this != PlayHands.left;
  bool get playsLeft => this != PlayHands.right;

  bool plays(Hand hand) =>
      hand == Hand.right ? playsRight : playsLeft;
}

/// One written note: its sounding [midi] pitch plus the exact spelling to draw —
/// [letter] (0=C … 6=B) and scientific [octave] (C4 = middle C). [drawn] is the
/// accidental to render, non-null only when one was written explicitly (a note
/// covered by the key signature draws nothing).
class SongNote {
  const SongNote({
    required this.midi,
    required this.letter,
    required this.octave,
    this.drawn,
  });

  final int midi;
  final int letter;
  final int octave;
  final Accidental? drawn;

  /// The key to press, spelled as written — `F#4` in D major even though the
  /// signature means no accidental is drawn on the staff.
  String get name {
    final alteration = mod(mod(midi, 12) - naturalPitches[letter] + 6, 12) - 6;
    final sign = switch (alteration) {
      > 0 => '#',
      < 0 => 'b',
      _ => '',
    };
    return '${letterNames[letter]}$sign$octave';
  }
}

/// One rhythmic event in a voice: a strike of one or more [notes], or a rest
/// when they are empty. The [value] and [dotted] flag set its notated length.
class SongEvent {
  const SongEvent({
    required this.notes,
    required this.value,
    this.dotted = false,
  });

  final List<SongNote> notes;
  final NoteValue value;
  final bool dotted;

  bool get isRest => notes.isEmpty;

  List<int> get midiNotes => [for (final note in notes) note.midi];

  /// The keys to press, written the way the file does: a lone note by name, a
  /// chord bracketed. `null` for a rest.
  String? get label {
    if (isRest) return null;
    final names = [for (final note in notes) note.name];
    return names.length == 1 ? names.first : '[${names.join(' ')}]';
  }

  /// What the notes are called as a chord — `G`, `Am7`, `C/E` — or `null` when
  /// they are not three-or-more distinct pitches spelling a known shape.
  String? get chordName =>
      notes.length < 3 ? null : identifyChord(midiNotes)?.name;

  int get ticks => (value.ticks * (dotted ? 3 : 2)) ~/ 2;
}

typedef SongVoice = List<SongEvent>;

/// A vertical slice of the piece at one onset [tick]: the event (if any) that
/// begins there in each hand. [startsBar] marks a column landing on a barline.
class SongColumn {
  const SongColumn({
    required this.tick,
    this.rh,
    this.lh,
    this.startsBar = false,
  });

  final int tick;
  final SongEvent? rh;
  final SongEvent? lh;
  final bool startsBar;

  SongEvent? eventFor(Hand hand) => hand == Hand.right ? rh : lh;

  /// The notes [hands] must strike here — empty for a rest, or for a column
  /// only the other hand plays.
  List<int> notesFor(PlayHands hands) => [
    for (final hand in Hand.values)
      if (hands.plays(hand)) ...?eventFor(hand)?.midiNotes,
  ];
}

/// A piece of sheet music: two optional hands, its key and time signature, and
/// the merged onset [columns] the game walks through. Parsed from a `.song`
/// file by `parseSong`; there is no in-app editor by design.
class Song {
  Song({
    required this.title,
    required this.key,
    required this.beatsPerBar,
    required this.beatUnit,
    required this.rh,
    required this.lh,
    this.barlines = true,
  }) : columns = _buildColumns(rh, lh, beatsPerBar * (96 ~/ beatUnit));

  final String title;
  final MusicKey? key;
  final int beatsPerBar;
  final int beatUnit;

  /// Whether to draw the bars [beatsPerBar] implies. A chart of one chord per
  /// bar puts a line between every column, which separates nothing — `barlines:
  /// off` in the file turns them off without giving up the time signature.
  final bool barlines;
  final SongVoice? rh;
  final SongVoice? lh;
  final List<SongColumn> columns;

  SongVoice? voiceFor(Hand hand) => hand == Hand.right ? rh : lh;

  /// The hands the piece is actually written for, so a one-hand chart never
  /// draws an empty stave.
  Set<Hand> get hands => {
    for (final hand in Hand.values)
      if (voiceFor(hand) != null) hand,
  };
}

/// Merges the two voices onto one tick timeline, one column per distinct onset.
List<SongColumn> _buildColumns(SongVoice? rh, SongVoice? lh, int barTicks) {
  final rhAt = _onsets(rh);
  final lhAt = _onsets(lh);
  final ticks = {...rhAt.keys, ...lhAt.keys}.toList()..sort();
  return [
    for (final tick in ticks)
      SongColumn(
        tick: tick,
        rh: rhAt[tick],
        lh: lhAt[tick],
        startsBar: barTicks > 0 && tick % barTicks == 0,
      ),
  ];
}

Map<int, SongEvent> _onsets(SongVoice? voice) {
  final at = <int, SongEvent>{};
  if (voice == null) return at;
  var tick = 0;
  for (final event in voice) {
    at[tick] = event;
    tick += event.ticks;
  }
  return at;
}
