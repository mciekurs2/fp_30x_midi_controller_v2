/// A notated note length. Cosmetic for grading — rounds are self-paced — but it
/// decides which notehead and rest glyph are drawn, and how wide a column is.
enum NoteValue {
  semiquaver(6),
  quaver(12),
  crotchet(24),
  minim(48),
  semibreve(96);

  const NoteValue(this.ticks);

  /// Length in ticks, 24 to the quarter note — a grid fine enough for every
  /// value down to the (dotted) sixteenth without floating-point drift.
  final int ticks;
}
