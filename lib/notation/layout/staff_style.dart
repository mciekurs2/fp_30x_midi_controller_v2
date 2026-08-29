import 'glyph.dart';

/// The fixed glyph/staff scale every mode draws at, so notation is exactly the
/// same size whichever exercise is on screen. Everything else here is a
/// fraction of it, via [staffSpace].
const staffScale = 330.0;

/// One staff space in pixels — fixed, never fitted to the layout.
const staffSpace = StaffMetrics.space * staffScale;

/// The name under the staff and, where a column captions it, the line beneath —
/// in staff spaces.
const labelSize = 1.6;
const captionSize = 1.7;

/// The key a round is being played in, named at the top of the screen. Standing
/// context, not the thing being asked for, so it is drawn under [labelSize].
const keyNameSize = 1.0;

/// How far a name travels as it arrives and leaves, as a fraction of the width
/// — it is centred, so this is how far off-centre it starts and ends.
const labelSlide = 0.2;

/// Arrival is the length of a scroll; the exit is shorter, so two names are
/// never both near the middle for long.
const labelIn = Duration(milliseconds: 340);
const labelOut = Duration(milliseconds: 150);

/// How long the score takes to slide one column to the left.
const scrollDuration = Duration(milliseconds: 340);

/// A jump further than this (a restart, or the song looping) snaps instead of
/// scrolling the whole way back.
const snapDistance = 2;

/// How many onset columns are shown at once: the current one plus two ahead.
const scoreWindow = 3;

/// The clef's left edge, matching the single-note staff's inset, in pixels.
const clefMargin = 12.0;

/// Width reserved for the clef before the key signature, in staff spaces.
const clefBox = 3.4;

/// Half the distance between the two staff centres, in spaces.
///
/// Widened from 3 when chords gained real stems, and again to print's own five
/// when those stems took their full engraved length. At 3 the staves left two
/// clear spaces between them and a bass chord's stem reaching up met a treble
/// note hanging below its staff — `blue.song`'s right hand reaches down to B3
/// — so the two read as one line through the system. At 4 the same happened
/// once a bass octave's stem reached an octave past its top head: `[G2 D3 G3]`
/// tips out exactly where B3 hangs. Five clears it by two spaces, and it costs
/// no height: the staves are centred in whatever box the view is given.
const staffHalfGap = 5.0;

/// Opacity by distance ahead of the cursor: the current column is solid, the
/// upcoming ones fade back, and the fourth is invisible — so a column fades in
/// as it scrolls into the window rather than popping into view.
const slotAlpha = [1.0, 0.45, 0.3, 0.0];

/// How much of a column's travel the outgoing note fades over. Sized so it is
/// fully invisible before it could reach the key signature.
const fadeOutSpan = 0.45;

/// Clear space between one column's ink and the next, in staff spaces. Columns
/// are spaced by their actual ink extents (accidentals and dots included), so
/// this is a real gap rather than a hoped-for one.
const columnGap = 1.7;

/// The least the gap may be squeezed to when a run of wide columns would
/// otherwise reach off the right edge.
const minColumnGap = 0.8;

/// Breathing room kept clear at the right edge, in staff spaces.
const rightMargin = 1.0;

/// Between the key signature and the first note, in staff spaces.
const signatureLeadGap = 1.5;

/// Tint of the staff lines against the notation colour.
const staffLineAlpha = 220;

/// How far a barline is dimmed against the notes it divides.
const barlineAlpha = 0.6;
