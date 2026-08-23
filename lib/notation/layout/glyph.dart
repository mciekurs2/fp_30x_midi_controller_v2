import '../../domain/models/note_value.dart';
import '../../domain/models/pitch.dart';

/// A SMuFL glyph: its codepoint and the ink width, in staff spaces, from the
/// font's metadata.
enum MusicSymbol {
  brace('\uE000', 0.277),
  gClef('\uE050', 2.684),
  fClef('\uE062', 2.736),
  noteWhole('\uE1D2', 1.688),
  noteHalfUp('\uE1D3', 1.364),
  noteHalfDown('\uE1D4', 1.364),
  noteQuarterUp('\uE1D5', 1.328),
  noteQuarterDown('\uE1D6', 1.328),
  note8thUp('\uE1D7', 2.264),
  note8thDown('\uE1D8', 1.328),
  accidentalFlat('\uE260', 0.904),
  accidentalNatural('\uE261', 0.672),
  accidentalSharp('\uE262', 0.996),
  restWhole('\uE4E3', 1.128),
  restHalf('\uE4E4', 1.128),
  restQuarter('\uE4E5', 0.612),
  rest8th('\uE4E6', 0.632),
  augmentationDot('\uE1E7', 0.3);

  const MusicSymbol(this.char, this.width);

  final String char;
  final double width;
}

extension AccidentalGlyph on Accidental {
  MusicSymbol get symbol => switch (this) {
    Accidental.sharp => MusicSymbol.accidentalSharp,
    Accidental.flat => MusicSymbol.accidentalFlat,
    Accidental.natural => MusicSymbol.accidentalNatural,
  };
}

extension NoteValueGlyph on NoteValue {
  /// SMuFL ships each value stemmed both ways, registered on the notehead; the
  /// stemless semibreve ignores direction.
  MusicSymbol notehead({required bool stemDown}) =>
      switch ((this, stemDown)) {
        (NoteValue.quaver, false) => MusicSymbol.note8thUp,
        (NoteValue.quaver, true) => MusicSymbol.note8thDown,
        (NoteValue.crotchet, false) => MusicSymbol.noteQuarterUp,
        (NoteValue.crotchet, true) => MusicSymbol.noteQuarterDown,
        (NoteValue.minim, false) => MusicSymbol.noteHalfUp,
        (NoteValue.minim, true) => MusicSymbol.noteHalfDown,
        (NoteValue.semibreve, _) => MusicSymbol.noteWhole,
      };

  /// The rest glyph of the same value, for a silent beat.
  MusicSymbol get rest => switch (this) {
    NoteValue.semibreve => MusicSymbol.restWhole,
    NoteValue.minim => MusicSymbol.restHalf,
    NoteValue.crotchet => MusicSymbol.restQuarter,
    NoteValue.quaver => MusicSymbol.rest8th,
  };

  /// The whole note carries no stem, so it centres on its own wider head.
  double get leftEdge =>
      this == NoteValue.semibreve ? StaffMetrics.wholeNoteX : StaffMetrics.noteX;

  /// Notehead ink width, for sizing ledger lines under it.
  double get headWidth => this == NoteValue.semibreve
      ? MusicSymbol.noteWhole.width
      : MusicSymbol.noteQuarterUp.width;
}

/// Staff geometry in fractions of the square, measured in **staff spaces** (one
/// em = four spaces, the SMuFL unit). Bravura registers every glyph on its own
/// origin, so placement is arithmetic.
class StaffMetrics {
  StaffMetrics._();

  /// PostScript name, matching the family registered in pubspec.yaml.
  static const musicFace = 'Bravura';

  /// Room above and below the four staff spaces for ledgers, stems and
  /// accidentals. Tightened from 6.3 to scale the staff and glyphs ~1.4× for
  /// phone legibility.
  static const headroom = 3.93;
  static const squareSpaces = 4 + 2 * headroom;

  static const space = 1 / squareSpaces;
  static const halfStep = space / 2;
  static const middleLine = 0.5;

  /// Four staff spaces per em, the only staff-to-type conversion.
  static double fontSize(double side) => 4 * space * side;

  /// Bravura's engraving defaults, so drawn lines match the font's weight.
  static const staffLineThickness = space * 0.13;
  static const barlineThickness = space * 0.16;
  static const ledgerLineThickness = space * 0.16;

  /// How far a ledger line reaches past the notehead on each side.
  static const ledgerLineExtension = 0.4;

  /// Where the staff (and barline) begins, from the square's centre.
  static const staffStart = -0.43;
  static const staffStartFraction = 0.5 + staffStart;

  /// Where the lines fade out, and how far in they stop registering — used to
  /// find where the system appears to end.
  static const fadeStart = 0.65;
  static const fadeVanish = 0.5;
  static const visualEnd = fadeStart + (1 - fadeStart) * fadeVanish;

  static const clefStart = -6.2;

  /// Left edge of the notehead, centred on the square (heads register at x 0).
  static final noteX = -MusicSymbol.noteQuarterUp.width / 2;

  /// The whole note's own left edge, centred (it is wider than a stemmed head).
  static final wholeNoteX = -MusicSymbol.noteWhole.width / 2;

  static const accidentalGap = 0.25;

  /// Between the last signature accidental and the notehead, and between one
  /// signature accidental and the next.
  static const signatureGap = 0.8;
  static const signatureStep = 0.1;

  /// How close two accidentals may sit, in diatonic steps, before the second is
  /// pushed into a column of its own.
  static const accidentalStack = 6;

  /// Horizontal pitch of the accidental columns.
  static final accidentalColumnStep = MusicSymbol.accidentalSharp.width * 0.6;

  /// A glyph's y in spaces above the middle line (positive up), per `steps`.
  static double y(int step) => step * 0.5;

  /// A step's y as a fraction of the square, for lines drawn from the top edge.
  static double line(int step) => middleLine - step * halfStep;
}
