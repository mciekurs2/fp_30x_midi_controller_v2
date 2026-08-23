import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/note_value.dart';
import '../layout/glyph.dart';
import '../layout/score_layout.dart';
import '../layout/staff_style.dart';
import '../model/staff_placement.dart';
import 'glyph_cache.dart';

/// Ledger lines, noteheads and accidentals for one stack of notes centred at
/// [x]. Written notes and held keys both come through here, so a key is drawn
/// exactly the way the note it answers is.
///
/// [colors] runs parallel to [placements]. [accidentalColumns] carries the
/// staff steps already placed, so an overlay can be fitted around a target that
/// was laid out first — the target's accidentals never shift, and a held key on
/// a step the target already has lands on the very accidental it is answering.
void paintMarks(
  Canvas canvas, {
  required List<StaffPlacement> placements,
  required List<Color> colors,
  required NoteValue value,
  required double x,
  required double centerY,
  AccidentalColumns? accidentalColumns,
}) {
  // A step is one staff position, so two notes never contend for a ledger line
  // and the last writer is the only writer.
  final ledgers = <int, Color>{
    for (var i = 0; i < placements.length; i++)
      for (final step in placements[i].ledgerSteps) step: colors[i],
  };
  final ledgerWidth =
      (value.headWidth + 2 * StaffMetrics.ledgerLineExtension) * staffSpace;
  ledgers.forEach((step, tint) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, centerY - StaffMetrics.y(step) * staffSpace),
        width: ledgerWidth,
        height: StaffMetrics.ledgerLineThickness * staffScale,
      ),
      Paint()..color = tint,
    );
  });

  for (var i = 0; i < placements.length; i++) {
    GlyphCache.paint(
      canvas,
      value.notehead(stemDown: placements[i].stemDown),
      x + value.leftEdge * staffSpace,
      StaffMetrics.y(placements[i].steps),
      centerY,
      colors[i],
    );
  }

  for (final slot in accidentalSlots(
    placements,
    value,
    columns: accidentalColumns,
  )) {
    final accidental = slot.placement.accidental!;
    GlyphCache.paint(
      canvas,
      accidental.symbol,
      x + (slot.right - accidental.symbol.width) * staffSpace,
      StaffMetrics.y(slot.placement.steps),
      centerY,
      colors[slot.index],
    );
  }
}

/// The rest glyph for a silent beat, centred at [x].
void paintRest(
  Canvas canvas,
  NoteValue value,
  double x,
  double centerY,
  Color color,
) => GlyphCache.paint(
  canvas,
  value.rest,
  x - value.rest.width / 2 * staffSpace,
  // The whole rest hangs under the fourth line; the others sit at the middle.
  value == NoteValue.semibreve ? StaffMetrics.y(2) : 0,
  centerY,
  color,
);

/// The augmentation dot, nudged into the space when the note sits on a line.
void paintDot(
  Canvas canvas,
  List<StaffPlacement> placements,
  NoteValue value,
  double x,
  double centerY,
  Color color,
) {
  if (placements.isEmpty) return;
  final top = placements.map((p) => p.steps).reduce(math.max);
  GlyphCache.paint(
    canvas,
    MusicSymbol.augmentationDot,
    x + (value.headWidth / 2 + 0.3) * staffSpace,
    StaffMetrics.y(top.isEven ? top + 1 : top),
    centerY,
    color,
  );
}
