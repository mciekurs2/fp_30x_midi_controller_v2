import 'dart:math' as math;

import '../../domain/models/note_value.dart';
import '../model/staff_placement.dart';
import 'glyph.dart';

/// A stack of noteheads resolved for drawing: one stem for the whole chord, and
/// where each head sits across it.
///
/// A chord has exactly one stem, in one direction, and two heads a diatonic
/// step apart cannot both sit on the same side of it — they would print on top
/// of each other. Deciding both here, once and purely, is what lets the
/// painter, the column measurement and the held-key overlay draw the same chord
/// the same way.
class ChordLayout {
  ChordLayout._(
    this._offsets, {
    required this.value,
    required this.stemDown,
    required this.heads,
    required this.steps,
    required this.stem,
    required this.stemAnchor,
    required this.left,
    required this.right,
    required this.headRight,
  });

  /// A voice with nothing on it — a rest, or an empty overlay.
  const ChordLayout.empty(this.value)
    : stemDown = false,
      heads = const [],
      steps = const [],
      stem = null,
      stemAnchor = 0,
      left = 0,
      right = 0,
      headRight = 0,
      _offsets = const {};

  final NoteValue value;

  /// One direction for the whole chord: the head furthest from the middle line
  /// decides, and a tie hangs down.
  final bool stemDown;

  /// Each head's left edge in staff spaces from the column centre, parallel to
  /// the placements this was built from. A head displaced across the stem is
  /// one notehead further out than the rest.
  final List<double> heads;

  /// Each head's staff step, parallel to [heads].
  final List<int> steps;

  /// The stem in staff spaces: [x] its left edge from the column centre, [from]
  /// the head it grows out of and [to] its tip, both measured up from the
  /// middle line. `null` on a semibreve, which carries no stem.
  final ({double x, double from, double to})? stem;

  /// Which head the stem grows out of, so it is drawn in that head's colour.
  final int stemAnchor;

  /// Ink either side of the column centre, in staff spaces: heads, stem and
  /// flag. Accidentals and the augmentation dot are the caller's to add.
  final double left;
  final double right;

  /// The rightmost head's right edge — where the augmentation dot hangs, which
  /// a flag must not push out.
  final double headRight;

  final Map<int, double> _offsets;

  bool get isEmpty => heads.isEmpty;

  /// The leftmost head's left edge, signed from the column centre. Accidentals
  /// hang from here, so a head displaced left is cleared rather than struck
  /// through.
  double get headLeft => isEmpty ? value.leftEdge : -left;

  /// Where this chord put the head on [step], for an overlay to follow.
  double? offsetFor(int step) => _offsets[step];
}

/// Lays out one stack of noteheads.
///
/// [follow] is the written chord an overlay is being drawn over. A held key
/// inherits the target's stem direction and the exact offset of any step the
/// target already writes, so a green head lands on the very notehead it is
/// answering rather than half a head-width beside it — the same contract
/// `overlayColumns` keeps for accidentals. A key the target does not ask for is
/// still fitted around it, and stretches the stem to reach itself.
ChordLayout layoutChord(
  List<StaffPlacement> placements,
  NoteValue value, {
  ChordLayout? follow,
}) {
  if (placements.isEmpty) return ChordLayout.empty(value);

  final steps = [for (final placement in placements) placement.steps];
  final top = steps.reduce(math.max);
  final bottom = steps.reduce(math.min);
  final stemDown = follow?.stemDown ?? top >= -bottom;

  // Walk from the end the stem attaches to, so a displaced head is always
  // measured against one that stayed on the main side.
  final order = [for (var i = 0; i < steps.length; i++) i]
    ..sort(
      (a, b) => stemDown
          ? steps[b].compareTo(steps[a])
          : steps[a].compareTo(steps[b]),
    );

  final main = value.leftEdge;
  // The displaced head shares the stem rather than clearing it, which is what
  // keeps the pair reading as one chord instead of two columns.
  final across =
      (value.headWidth - StaffMetrics.stemWidth) * (stemDown ? -1 : 1);

  final offsets = <int, double>{...?follow?._offsets};
  final taken = <int>{};
  final heads = List<double>.filled(placements.length, main);
  for (final i in order) {
    final step = steps[i];
    if (taken.contains(step)) {
      // Two heads on one step — an F natural beside an F sharp. The second
      // crosses the stem so the pair does not print as one blot.
      heads[i] = offsets[step] == main ? main + across : main;
      continue;
    }
    taken.add(step);
    if (offsets[step] case final inherited?) {
      heads[i] = inherited;
      continue;
    }
    final crowded = offsets[step - 1] == main || offsets[step + 1] == main;
    heads[i] = crowded ? main + across : main;
    offsets[step] = heads[i];
  }

  final anchorStep = stemDown ? top : bottom;
  final stemAnchor = steps.indexOf(anchorStep);
  final flag = value.flag(stemDown: stemDown);

  ({double x, double from, double to})? stem;
  if (value.stemmed) {
    double from;
    double to;
    if (follow?.stem case final over?) {
      // The tip is the written stem's, so the overlay lies along it instead of
      // shooting past the moment a chord's top note alone goes down — only a
      // head the target never wrote may push it further. The foot is the
      // overlay's own lowest head, so what is tinted is the stem the keys
      // actually down reach along.
      from = StaffMetrics.y(anchorStep);
      to = over.to;
      for (var i = 0; i < steps.length; i++) {
        if (follow!.offsetFor(steps[i]) != null) continue;
        final y = StaffMetrics.y(steps[i]);
        to = stemDown
            ? math.min(to, y - StaffMetrics.stemOverhang)
            : math.max(to, y + StaffMetrics.stemOverhang);
      }
    } else {
      from = StaffMetrics.y(anchorStep);
      // Measured from the head the stem grows out of, and lengthened only when
      // the chord is wider than that — never a fixed reach past the far head,
      // which on an octave would run the tip into the next stave.
      final far = StaffMetrics.y(stemDown ? bottom : top);
      final reach = math.max(
        StaffMetrics.stemLength,
        (far - from).abs() + StaffMetrics.stemOverhang,
      );
      to = stemDown ? from - reach : from + reach;
    }
    stem = (
      x: stemDown ? main : main + value.headWidth - StaffMetrics.stemWidth,
      from: from,
      to: to,
    );
  }

  final headRight = heads.reduce(math.max) + value.headWidth;
  var right = headRight;
  if (stem != null && flag != null) {
    right = math.max(right, stem.x + flag.width);
  }

  return ChordLayout._(
    offsets,
    value: value,
    stemDown: stemDown,
    heads: heads,
    steps: steps,
    stem: stem,
    stemAnchor: stemAnchor < 0 ? 0 : stemAnchor,
    left: -heads.reduce(math.min),
    right: right,
    headRight: headRight,
  );
}
