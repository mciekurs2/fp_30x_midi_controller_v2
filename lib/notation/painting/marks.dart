import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/note_value.dart';
import '../layout/chord_layout.dart';
import '../layout/glyph.dart';
import '../layout/score_layout.dart';
import '../layout/staff_style.dart';
import '../model/staff_placement.dart';
import 'glyph_cache.dart';

/// Ledger lines, noteheads, one shared stem and accidentals for a stack of
/// notes centred at [x]. Written notes and held keys both come through here, so
/// a key is drawn exactly the way the note it answers is.
///
/// [colors] runs parallel to [placements]. [follow] is the written chord an
/// overlay is drawn over: it fixes the stem's direction and where a head on a
/// step the target already writes sits, so a held key lands on the very
/// notehead it is answering. [accidentalColumns] does the same for the
/// accidentals — see [overlayColumns].
///
/// Returns the chord it laid out, so the caller can hang a dot off it.
ChordLayout paintMarks(
  Canvas canvas, {
  required List<StaffPlacement> placements,
  required List<Color> colors,
  required NoteValue value,
  required double x,
  required double centerY,
  ChordLayout? follow,
  AccidentalColumns? accidentalColumns,
}) {
  final chord = layoutChord(placements, value, follow: follow);
  if (chord.isEmpty) return chord;

  double spacesToY(double spaces) => centerY - spaces * staffSpace;

  // One ledger line per step, spanning every head that needs it — a head
  // displaced across the stem would otherwise hang off the end of its own.
  final ledgers = <int, ({double left, double right, Color color})>{};
  for (var i = 0; i < placements.length; i++) {
    for (final step in placements[i].ledgerSteps) {
      final left = chord.heads[i] - StaffMetrics.ledgerLineExtension;
      final right =
          chord.heads[i] + value.headWidth + StaffMetrics.ledgerLineExtension;
      final drawn = ledgers[step];
      ledgers[step] = drawn == null
          ? (left: left, right: right, color: colors[i])
          : (
              left: math.min(drawn.left, left),
              right: math.max(drawn.right, right),
              color: colors[i],
            );
    }
  }
  final ledgerThickness = StaffMetrics.ledgerLineThickness * staffScale;
  ledgers.forEach((step, span) {
    final y = spacesToY(StaffMetrics.y(step));
    canvas.drawRect(
      Rect.fromLTRB(
        x + span.left * staffSpace,
        y - ledgerThickness / 2,
        x + span.right * staffSpace,
        y + ledgerThickness / 2,
      ),
      Paint()..color = span.color,
    );
  });

  // The stem before the heads, so a head covers where it joins.
  if (chord.stem case final stem?) {
    final tint = colors[chord.stemAnchor];
    canvas.drawRect(
      Rect.fromLTRB(
        x + stem.x * staffSpace,
        spacesToY(math.max(stem.from, stem.to)),
        x + (stem.x + StaffMetrics.stemWidth) * staffSpace,
        spacesToY(math.min(stem.from, stem.to)),
      ),
      Paint()..color = tint,
    );
    if (value.flag(stemDown: chord.stemDown) case final flag?) {
      GlyphCache.paint(
        canvas,
        flag,
        x + stem.x * staffSpace,
        stem.to,
        centerY,
        tint,
      );
    }
  }

  for (var i = 0; i < placements.length; i++) {
    GlyphCache.paint(
      canvas,
      value.notehead,
      x + chord.heads[i] * staffSpace,
      StaffMetrics.y(placements[i].steps),
      centerY,
      colors[i],
    );
  }

  for (final slot in accidentalSlots(
    placements,
    accidentalColumns ?? AccidentalColumns(base: chord.headLeft),
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
  return chord;
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

/// The augmentation dot, hung off the rightmost notehead so a head displaced
/// across the stem does not sit on it, and nudged into the space when the note
/// it belongs to is on a line.
void paintDot(
  Canvas canvas,
  ChordLayout chord,
  double x,
  double centerY,
  Color color,
) {
  if (chord.isEmpty) return;
  final top = chord.steps.reduce(math.max);
  GlyphCache.paint(
    canvas,
    MusicSymbol.augmentationDot,
    x + (chord.headRight + dotGap) * staffSpace,
    StaffMetrics.y(top.isEven ? top + 1 : top),
    centerY,
    color,
  );
}
