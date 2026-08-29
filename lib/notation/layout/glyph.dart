import '../../domain/models/note_value.dart';
import '../../domain/models/pitch.dart';

/// A SMuFL glyph: its codepoint and the ink width, in staff spaces, from the
/// font's metadata.
enum MusicSymbol {
  brace('\uE000', 0.277),
  gClef('\uE050', 2.684),
  fClef('\uE062', 2.736),
  noteheadWhole('\uE0A2', 1.688),
  noteheadHalf('\uE0A3', 1.18),
  noteheadBlack('\uE0A4', 1.18),
  flag8thUp('\uE240', 1.056),
  flag8thDown('\uE241', 1.224),
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
  /// The notehead alone. SMuFL also ships heads with the stem baked in, but a
  /// chord shares *one* stem between its heads, which no composite glyph can
  /// express — so stems are drawn, not written.
  MusicSymbol get notehead => switch (this) {
    NoteValue.semibreve => MusicSymbol.noteheadWhole,
    NoteValue.minim => MusicSymbol.noteheadHalf,
    NoteValue.crotchet || NoteValue.quaver => MusicSymbol.noteheadBlack,
  };

  /// The flag at the stem's tip, or `null` where the value carries none.
  MusicSymbol? flag({required bool stemDown}) => this != NoteValue.quaver
      ? null
      : stemDown
      ? MusicSymbol.flag8thDown
      : MusicSymbol.flag8thUp;

  /// The semibreve is the one value drawn without a stem.
  bool get stemmed => this != NoteValue.semibreve;

  /// The whole note carries no stem, so it centres on its own wider head.
  double get leftEdge => this == NoteValue.semibreve
      ? StaffMetrics.wholeNoteX
      : StaffMetrics.noteX;

  /// Notehead ink width, for sizing ledger lines under it.
  double get headWidth => this == NoteValue.semibreve
      ? MusicSymbol.noteheadWhole.width
      : MusicSymbol.noteheadBlack.width;

  /// The rest glyph of the same value, for a silent beat.
  MusicSymbol get rest => switch (this) {
    NoteValue.semibreve => MusicSymbol.restWhole,
    NoteValue.minim => MusicSymbol.restHalf,
    NoteValue.crotchet => MusicSymbol.restQuarter,
    NoteValue.quaver => MusicSymbol.rest8th,
  };
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

  /// The stem's width in **staff spaces** — the layout works in those, and
  /// [stemThickness] is the same number as a fraction of the square, for the
  /// painter. Bravura's engraving default.
  static const stemWidth = 0.12;
  static const stemThickness = space * stemWidth;

  /// How long a stem is, in staff spaces, measured from the head it grows out
  /// of — so a stem-up triad's tip lands around the middle line, as engraved.
  static const stemLength = 3.5;

  /// The least a stem may show past the head at its far end. A chord wider than
  /// [stemLength] lengthens to this instead of keeping the nominal length: a
  /// stem measured past the *far* head would put a bass chord's tip through the
  /// treble stave.
  static const stemOverhang = 1.0;

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
  static final noteX = -MusicSymbol.noteheadBlack.width / 2;

  /// The whole note's own left edge, centred (it is wider than a stemmed head).
  static final wholeNoteX = -MusicSymbol.noteheadWhole.width / 2;

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
