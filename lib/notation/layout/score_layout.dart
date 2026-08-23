import 'dart:math' as math;

import '../../domain/models/music_key.dart';
import '../../domain/models/note_value.dart';
import '../../domain/models/pitch.dart';
import '../model/clef.dart';
import '../model/score.dart';
import '../model/spelling.dart';
import '../model/staff_placement.dart';
import 'glyph.dart';
import 'staff_style.dart';

/// Where one stave's middle line sits, in pixels down the drawing area.
typedef StaveLayout = ({Clef clef, double centerY, int index});

/// How far a column's ink reaches either side of its centre, in staff spaces.
typedef Extent = ({double left, double right});

/// An accidental's place beside its notehead: [right] is its right edge in
/// staff spaces from the notehead centre (negative — accidentals hang left), so
/// a flat and a sharp sharing a column still hang flush.
typedef AccidentalSlot = ({int index, StaffPlacement placement, double right});

/// How a score's columns are placed across the width.
enum ScoreAlignment {
  /// One column, centred — stepped right only as far as a key signature makes
  /// necessary. What every single-note and chord exercise draws.
  centered,

  /// Columns laid left to right from the signature, scrolling under a cursor.
  /// What a piece of sheet music draws.
  flowing,
}

/// Column measurements for one score. Held across frames by the widget, because
/// they follow from the score and the width — not from where the cursor is.
/// (v1 cached these in module-level variables, which two staves on screen at
/// once would have thrashed.)
class ScoreMeasure {
  ScoreMeasure(this.score) {
    _staves = [
      for (var i = 0; i < score.staves.length; i++)
        (clef: score.staves[i].clef, index: i),
    ];
  }

  final Score score;
  late final List<({Clef clef, int index})> _staves;

  late final List<Extent> extents = [
    for (final column in score.columns) _columnExtent(column),
  ];

  /// Whether any column captions a chord, fixing the name rows' height for the
  /// whole score so a chordless column does not close the gap and jog the rows
  /// as the cursor advances.
  bool get hasCaptions => score.hasCaptions;

  double? _gap;
  double? _gapWidth;

  /// The gap used between every column: the target gap unless the score's
  /// widest run of [scoreWindow] columns needs it squeezed to fit.
  double gapFor(double width, double lead) {
    if (_gap case final cached? when _gapWidth == width) return cached;

    final ink = [for (final e in extents) e.left + e.right];
    var worst = 0.0;
    for (var i = 0; i < ink.length; i++) {
      var run = 0.0;
      for (var j = i; j < i + scoreWindow && j < ink.length; j++) {
        run += ink[j];
      }
      worst = math.max(worst, run);
    }

    final room = (width - lead) / staffSpace - rightMargin;
    final spans = math.max(1, scoreWindow - 1);
    _gapWidth = width;
    return _gap = worst + columnGap * spans <= room
        ? columnGap
        : ((room - worst) / spans).clamp(minColumnGap, columnGap);
  }

  Extent _columnExtent(ScoreColumn column) {
    var left = 0.0;
    var right = 0.0;
    for (final stave in _staves) {
      final voice = column.voices.elementAtOrNull(stave.index);
      if (voice == null) continue;
      final extent = voiceExtent(voice, stave.clef, score.spelling);
      left = math.max(left, extent.left);
      right = math.max(right, extent.right);
    }
    return (left: left, right: right);
  }
}

/// Everything needed to place a frame's columns. Pure geometry — the painter
/// and the label widgets read the same numbers, so the two never drift apart.
class ScoreLayout {
  const ScoreLayout({
    required this.staves,
    required this.lead,
    required this.gap,
    required this.position,
    required this.base,
    required this.shift,
    required this.first,
    required this.last,
    required this.xs,
    required this.extents,
    required this.clipLeft,
    required this.fadeStart,
    required this.alignment,
  });

  final List<StaveLayout> staves;

  /// Where the notes begin, past the clef and key signature.
  final double lead;

  /// One gap between every column in the score.
  final double gap;

  /// The continuous cursor and its floored column.
  final double position;
  final int base;

  /// How far the whole run is slid left so [base] lands at [lead].
  final double shift;

  /// The visible column range — one back and one past the window, so a note has
  /// somewhere to scroll in from and out to.
  final int first;
  final int last;

  /// Each visible column's centre x in the unshifted run, in pixels.
  final Map<int, double> xs;
  final Map<int, Extent> extents;

  /// Left edge scrolling content is clipped to.
  final double clipLeft;

  /// Where the staff lines start fading, as a fraction of the width.
  final double fadeStart;

  final ScoreAlignment alignment;

  bool get isEmpty => first > last;

  double get topStaveY => staves.first.centerY;
  double get bottomStaveY => staves.last.centerY;

  /// The on-screen centre x of column [i].
  double columnX(int i) => (xs[i] ?? 0) + shift;

  /// Opacity of column [i] at the current [position]. A centred score never
  /// scrolls, so its one column is always solid.
  double alphaAt(int i) =>
      alignment == ScoreAlignment.centered ? 1 : _alphaAt(i - position);

  /// How far below the bottom stave's middle line the first name row sits.
  double get labelDropSpaces =>
      staves.length > 1 ? labelDropGrand : labelDrop;
}

/// Lays [score] out for a viewport of [width] × [height], with the cursor at a
/// fractional [position] so the run can be interpolated between columns.
ScoreLayout layoutScore(
  ScoreMeasure measure, {
  required double position,
  required double width,
  required double height,
  ScoreAlignment? alignment,
}) {
  final score = measure.score;
  final mode =
      alignment ??
      (score.columns.length > 1
          ? ScoreAlignment.flowing
          : ScoreAlignment.centered);
  final staves = _stavesFor(score, height / 2);
  final lead = leadFor(score, staves.first.clef);

  if (mode == ScoreAlignment.centered) {
    return _centeredLayout(measure, staves, lead, width, height);
  }

  final gap = measure.gapFor(width, lead);
  final base = position.floor();
  // One column back so a played note can slide out, one past the window so the
  // next fades in as it arrives.
  final first = math.max(0, base - 1);
  final last = math.min(score.columns.length - 1, base + scoreWindow);

  final extents = <int, Extent>{};
  final xs = <int, double>{};
  var pen = 0.0;
  for (var i = first; i <= last; i++) {
    final extent = measure.extents[i];
    extents[i] = extent;
    xs[i] = pen + extent.left * staffSpace;
    pen = xs[i]! + (extent.right + gap) * staffSpace;
  }

  // Slide the run so the current column sits at the anchor; interpolating the
  // shift between one column and the next is what makes the score scroll.
  double anchorFor(int i) {
    final index = i.clamp(first, last);
    return lead + extents[index]!.left * staffSpace - xs[index]!;
  }

  final shift = first > last
      ? 0.0
      : _lerp(anchorFor(base), anchorFor(base + 1), position - base);

  return ScoreLayout(
    staves: staves,
    lead: lead,
    gap: gap,
    position: position,
    base: base,
    shift: shift,
    first: first,
    last: last,
    xs: xs,
    extents: extents,
    clipLeft: lead - signatureLeadGap * staffSpace,
    fadeStart: StaffMetrics.fadeStart,
    alignment: mode,
  );
}

/// One column, centred as every other mode draws it — but a key signature holds
/// the left of the staff, so the notes step right just far enough to clear its
/// last accidental, and the lines' fade start moves out to match or the notes
/// would land on lines that had already faded away.
ScoreLayout _centeredLayout(
  ScoreMeasure measure,
  List<StaveLayout> staves,
  double lead,
  double width,
  double height,
) {
  final score = measure.score;
  final clef = staves.first.clef;
  final value = score.columns.isEmpty
      ? NoteValue.crotchet
      : (score.columns.first.voices.firstOrNull?.value ?? NoteValue.crotchet);

  var centerX = width / 2;
  var fadeStart = StaffMetrics.fadeStart;
  if (score.drawnSignature case final key?) {
    // A gap, then half a notehead: the column's centre, not its left edge.
    final clearance =
        (StaffMetrics.signatureGap - value.leftEdge) *
        StaffMetrics.space *
        staffScale;
    centerX = math.max(centerX, signatureRight(key, clef) + clearance);
    if (width > 0) {
      final right =
          centerX +
          (value.leftEdge + value.headWidth + 1) *
              StaffMetrics.space *
              staffScale;
      fadeStart = math.min(
        0.95,
        math.max(StaffMetrics.fadeStart, right / width),
      );
    }
  }

  final has = score.columns.isNotEmpty;
  return ScoreLayout(
    staves: staves,
    lead: lead,
    gap: 0,
    position: 0,
    base: 0,
    shift: 0,
    first: 0,
    last: has ? 0 : -1,
    xs: has ? {0: centerX} : const {},
    extents: has ? {0: measure.extents.first} : const {},
    clipLeft: 0,
    fadeStart: fadeStart,
    alignment: ScoreAlignment.centered,
  );
}

/// The staves actually drawn: two make a grand staff, joined at the left; one
/// is centred exactly where the single-note staff draws.
List<StaveLayout> _stavesFor(Score score, double middle) {
  if (score.staves.length > 1) {
    return [
      for (var i = 0; i < score.staves.length; i++)
        (
          clef: score.staves[i].clef,
          centerY: middle + (i == 0 ? -staffHalfGap : staffHalfGap) * staffSpace,
          index: i,
        ),
    ];
  }
  return [(clef: score.staves.first.clef, centerY: middle, index: 0)];
}

/// Where the notes begin: past the clef box and the key signature.
double leadFor(Score score, Clef clef) {
  var lead = clefMargin + clefBox * staffSpace;
  if (score.drawnSignature case final key?) {
    final pitch = key.accidental!.symbol.width + StaffMetrics.signatureStep;
    lead += key.accidentalCount * pitch * staffSpace;
  }
  return lead + signatureLeadGap * staffSpace;
}

/// Where the signature's accidentals begin and how far apart they sit, in
/// pixels. The painter draws them here and the note column has to clear them,
/// so both sides read the run from one place.
({double left, double pitch}) signatureRun(Accidental accidental, Clef clef) => (
  left:
      clefMargin +
      (clef.symbol.width + StaffMetrics.signatureGap) *
          StaffMetrics.space *
          staffScale,
  pitch:
      (accidental.symbol.width + StaffMetrics.signatureStep) *
      StaffMetrics.space *
      staffScale,
);

/// The right edge of [key]'s signature as drawn in [clef].
double signatureRight(MusicKey key, Clef clef) {
  final accidental = key.accidental!;
  final run = signatureRun(accidental, clef);
  return run.left +
      (key.accidentalCount - 1) * run.pitch +
      accidental.symbol.width * StaffMetrics.space * staffScale;
}

/// How far a voice's ink reaches either side of its centre, in staff spaces.
Extent voiceExtent(ScoreVoice voice, Clef clef, Spelling spelling) {
  if (voice.isRest) {
    final half = voice.value.rest.width / 2;
    return (left: half, right: half);
  }
  final placements = [
    for (final note in voice.notes) note.placeOn(clef, spelling),
  ];
  var left = -voice.value.leftEdge;
  for (final slot in accidentalSlots(placements, voice.value)) {
    left = math.max(left, -(slot.right - slot.placement.accidental!.symbol.width));
  }
  var right = voice.value.leftEdge + voice.value.headWidth;
  if (voice.dotted) {
    right = math.max(
      right,
      voice.value.headWidth / 2 + 0.3 + MusicSymbol.augmentationDot.width,
    );
  }
  return (left: left, right: right);
}

/// Accidental columns being handed out.
///
/// A target is laid out first, on its own, so what you are asked to play never
/// shifts as keys go down; an overlay is then fitted *around* it by passing the
/// same instance. A held key on a step the target already has gets that step's
/// place back — which is what lands it on the very accidental it is answering —
/// and any other takes the leftmost column clearing every step already in it.
class AccidentalColumns {
  final _grid = <List<int>>[];
  final _placed = <int, double>{};

  /// The right edge for an accidental on [step], in staff spaces from the
  /// notehead centre. Negative: accidentals hang to the left.
  double rightFor(int step, NoteValue value) =>
      _placed[step] ??= _assign(step, value);

  double _assign(int step, NoteValue value) {
    var col = 0;
    while (col < _grid.length &&
        !_grid[col].every(
          (s) => (s - step).abs() >= StaffMetrics.accidentalStack,
        )) {
      col++;
    }
    if (col == _grid.length) _grid.add([]);
    _grid[col].add(step);
    return value.leftEdge -
        StaffMetrics.accidentalGap -
        col * StaffMetrics.accidentalColumnStep;
  }
}

/// The grid one stave's overlay hangs its accidentals in.
///
/// Order is the whole point. [scored] is columned first, so a key that already
/// scored keeps the place it was drawn in while it is held — its column depends
/// only on the other scored keys, and that set changes only as keys are struck
/// or let go, never because a new target arrived. [target] is columned next, so
/// what you are asked to play still never shifts as *live* keys go down; those
/// are fitted last, by the painter. A step already placed keeps its column, so
/// a held key answering the target lands on the very accidental it answers.
AccidentalColumns overlayColumns({
  required List<StaffPlacement> scored,
  required List<StaffPlacement> target,
  required NoteValue value,
}) {
  final columns = AccidentalColumns();
  accidentalSlots(scored, value, columns: columns);
  accidentalSlots(target, value, columns: columns);
  return columns;
}

/// Where each accidental hangs beside its notehead. Close ones stack into
/// left-going columns so they never overlap; measuring and drawing both go
/// through this, so the reserved width is always the width actually used.
List<AccidentalSlot> accidentalSlots(
  List<StaffPlacement> placements,
  NoteValue value, {
  AccidentalColumns? columns,
}) {
  final marked = [
    for (var i = 0; i < placements.length; i++)
      if (placements[i].accidental != null) (index: i, p: placements[i]),
  ]..sort((a, b) => b.p.steps.compareTo(a.p.steps));

  final grid = columns ?? AccidentalColumns();
  return [
    for (final (:index, :p) in marked)
      (index: index, placement: p, right: grid.rightFor(p.steps, value)),
  ];
}

/// Opacity for a column [d] places ahead of the cursor, sampled continuously so
/// it fades smoothly while the score slides. Behind the cursor it fades out
/// over [fadeOutSpan] of a column.
double _alphaAt(double d) {
  if (d < 0) {
    // Squared so it drops away quickly rather than lingering into the clip.
    final t = (1 + d / fadeOutSpan).clamp(0.0, 1.0);
    return t * t;
  }
  if (d >= slotAlpha.length - 1) return slotAlpha.last;
  final i = d.floor();
  return _lerp(slotAlpha[i], slotAlpha[i + 1], d - i);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The stave a held key belongs to: with one stave, that one; with a grand
/// staff, split at middle C.
StaveLayout staveForNote(ScoreLayout layout, int note) =>
    layout.staves.length == 1
    ? layout.staves.first
    : (note >= 60 ? layout.staves.first : layout.staves.last);

/// How a held key is written.
///
/// A key the column actually asks for takes that note's own spelling, so it
/// lands exactly on the notehead it is answering — spelled conventionally, a Db
/// drew as a C#, a whole staff position out. Anything else is spelled the way
/// the score writes its notes.
StaffPlacement placeHeldNote(
  int note,
  Clef clef,
  ScoreColumn? column,
  int staveIndex,
  Spelling spelling,
) {
  final voice = column?.voices.elementAtOrNull(staveIndex);
  for (final written in voice?.notes ?? const <ScoreNote>[]) {
    if (written.midi == note && written.isSpelled) {
      return written.placeOn(clef, spelling);
    }
  }
  return StaffPlacement.inClef(note, clef, spelling);
}

/// A held key is drawn with the value of the note it is answering, so it
/// matches the notehead it lands on instead of always reading as a crotchet.
/// Where this stave rests, the other's value is the better guess.
NoteValue heldNoteValue(ScoreColumn? column, int staveIndex) {
  if (column == null) return NoteValue.crotchet;
  final own = column.voices.elementAtOrNull(staveIndex);
  if (own != null && !own.isRest) return own.value;
  for (final other in column.voices) {
    if (other != null && !other.isRest) return other.value;
  }
  return NoteValue.crotchet;
}
