import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/models/music_key.dart';
import '../../domain/models/note_value.dart';
import '../layout/chord_layout.dart';
import '../layout/glyph.dart';
import '../layout/score_layout.dart';
import '../layout/staff_style.dart';
import '../model/score.dart';
import '../model/staff_placement.dart';
import 'glyph_cache.dart';
import 'marks.dart';

const _lineSteps = [-4, -2, 0, 2, 4];

/// The five lines of every stave, spanning the full width.
///
/// A centred score fades them out at the right, so a lone note reads as sitting
/// on an open system; a flowing one holds them solid, because there its columns
/// carry the fade instead.
class StaffLinesPainter extends CustomPainter {
  const StaffLinesPainter({required this.layout, required this.color});

  final ScoreLayout layout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final tint = color.withAlpha(staffLineAlpha);
    final thickness = StaffMetrics.staffLineThickness * staffScale;
    final paint = Paint();
    if (layout.alignment == ScoreAlignment.centered) {
      paint.shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        [tint, tint, tint.withValues(alpha: 0)],
        [0, layout.fadeStart, 1],
      );
    } else {
      paint.color = tint;
    }

    for (final stave in layout.staves) {
      for (final step in _lineSteps) {
        final y = stave.centerY - StaffMetrics.y(step) * staffSpace;
        canvas.drawRect(
          Rect.fromLTWH(0, y - thickness / 2, size.width, thickness),
          paint,
        );
      }
    }

    if (layout.staves.length > 1) _paintConnector(canvas);
  }

  /// The vertical line at the left joining the staves into one system.
  void _paintConnector(Canvas canvas) {
    final top = layout.topStaveY - StaffMetrics.y(4) * staffSpace;
    final bottom = layout.bottomStaveY - StaffMetrics.y(-4) * staffSpace;
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        top,
        StaffMetrics.barlineThickness * staffScale,
        bottom - top,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(StaffLinesPainter old) =>
      old.color != color ||
      old.layout.fadeStart != layout.fadeStart ||
      old.layout.alignment != layout.alignment ||
      !listEquals(old.layout.staves, layout.staves);
}

/// The clef on each stave, pinned to the left margin so it is always visible.
class ClefPainter extends CustomPainter {
  const ClefPainter({required this.staves, required this.color});

  final List<StaveLayout> staves;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stave in staves) {
      GlyphCache.paint(
        canvas,
        stave.clef.symbol,
        clefMargin,
        stave.clef.origin,
        stave.centerY,
        color,
      );
    }
  }

  @override
  bool shouldRepaint(ClefPainter old) =>
      old.color != color || !listEquals(old.staves, staves);
}

/// The key signature, drawn once at the start of the system. It has to be read
/// once and held, so it never moves with the notes.
class SignaturePainter extends CustomPainter {
  const SignaturePainter({
    required this.staves,
    required this.musicKey,
    required this.color,
  });

  final List<StaveLayout> staves;
  final MusicKey musicKey;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final accidental = musicKey.accidental;
    if (accidental == null) return;
    final symbol = accidental.symbol;
    final pitch = (symbol.width + StaffMetrics.signatureStep) * staffSpace;
    final start = clefMargin + clefBox * staffSpace;

    for (final stave in staves) {
      final steps = signatureSteps(musicKey, stave.clef);
      for (var i = 0; i < steps.length; i++) {
        GlyphCache.paint(
          canvas,
          symbol,
          start + i * pitch,
          StaffMetrics.y(steps[i]),
          stave.centerY,
          color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter old) =>
      old.color != color ||
      old.musicKey != musicKey ||
      !listEquals(old.staves, staves);
}

/// The written notes of every visible column, each tinted by how far it is from
/// the cursor, plus the barlines between them.
class ColumnsPainter extends CustomPainter {
  const ColumnsPainter({
    required this.score,
    required this.layout,
    required this.color,
  });

  final Score score;
  final ScoreLayout layout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.isEmpty) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(layout.clipLeft, 0, size.width, size.height));

    for (var i = layout.first; i <= layout.last; i++) {
      final alpha = layout.alphaAt(i);
      if (alpha <= 0) continue;
      final column = score.columns[i];
      final x = layout.columnX(i);
      final tint = color.withValues(alpha: alpha);

      if (score.barlines && column.startsBar && i > 0) {
        _paintBarline(
          canvas,
          x - (layout.extents[i]!.left + layout.gap / 2) * staffSpace,
          tint,
        );
      }
      for (final stave in layout.staves) {
        final voice = column.voices.elementAtOrNull(stave.index);
        if (voice == null) continue;
        _paintVoice(canvas, voice, x, stave, tint);
      }
    }
    canvas.restore();
  }

  void _paintVoice(
    Canvas canvas,
    ScoreVoice voice,
    double x,
    StaveLayout stave,
    Color tint,
  ) {
    if (voice.isRest) {
      paintRest(canvas, voice.value, x, stave.centerY, tint);
      return;
    }
    final placements = [
      for (final note in voice.notes) note.placeOn(stave.clef, score.spelling),
    ];
    final chord = paintMarks(
      canvas,
      placements: placements,
      colors: [for (final _ in placements) tint],
      value: voice.value,
      x: x,
      centerY: stave.centerY,
    );
    if (voice.dotted) paintDot(canvas, chord, x, stave.centerY, tint);
  }

  void _paintBarline(Canvas canvas, double x, Color tint) {
    final top = layout.topStaveY - StaffMetrics.y(4) * staffSpace;
    final bottom = layout.bottomStaveY - StaffMetrics.y(-4) * staffSpace;
    canvas.drawRect(
      Rect.fromLTWH(
        x,
        top,
        StaffMetrics.barlineThickness * staffScale,
        bottom - top,
      ),
      Paint()..color = tint.withValues(alpha: tint.a * barlineAlpha),
    );
  }

  @override
  bool shouldRepaint(ColumnsPainter old) =>
      old.color != color ||
      !identical(old.score, score) ||
      old.layout.position != layout.position ||
      old.layout.shift != layout.shift ||
      old.layout.first != layout.first ||
      old.layout.last != layout.last;
}

/// A held key, resolved to how it is drawn.
typedef HeldNote = ({int note, StaffPlacement placement, int stave, Color color});

/// The player's held keys, over the column they are answering.
///
/// Grouped by stave so a handful of held keys column their accidentals against
/// each other, and drawn through the same ledger/notehead/accidental path the
/// written notes take — in v1 a played key on the single staff could otherwise
/// come out a bare notehead, with nothing to compare against what it answered.
class OverlayPainter extends CustomPainter {
  const OverlayPainter({
    required this.notes,
    required this.layout,
    required this.values,
    required this.target,
    required this.x,
    required this.clip,
    this.scored = const {},
  });

  final List<HeldNote> notes;
  final ScoreLayout layout;

  /// The note value held keys take on each stave, from the column they answer.
  final Map<int, NoteValue> values;

  /// The answered column's own placements, per stave. The target is columned
  /// first from these, so what you are asked to play never shifts as keys go
  /// down, and a held key on a step the target already has lands on the very
  /// accidental it is answering.
  final Map<int, List<StaffPlacement>> target;

  /// Which of [notes] already scored. They are columned *before* the target, so
  /// a fresh target's accidentals fit around them rather than shoving theirs
  /// left — a key that scored holds the place it was drawn in for as long as it
  /// is held, the way it holds its clef and its spelling. Their own columns
  /// depend only on each other, and that set changes only as keys are struck or
  /// let go. Empty where nothing is pinned, which leaves the target columned
  /// first exactly as before.
  final Set<int> scored;

  final double x;
  final bool clip;

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;
    canvas.save();
    if (clip) {
      canvas.clipRect(
        Rect.fromLTRB(layout.clipLeft, 0, size.width, size.height),
      );
    }

    for (final stave in layout.staves) {
      final mine = [
        for (final note in notes)
          if (note.stave == stave.index) note,
      ];
      if (mine.isEmpty) continue;
      final value = values[stave.index] ?? NoteValue.crotchet;
      final placements = [for (final n in mine) n.placement];
      final asked = target[stave.index] ?? const <StaffPlacement>[];
      // The target is laid out first and the overlay follows it, for heads and
      // accidentals alike: a held key then lands on the very notehead it is
      // answering, under the same stem, however the target's chord is spread.
      final written = asked.isEmpty ? null : layoutChord(asked, value);
      final columns = overlayColumns(
        scored: [
          for (final note in mine)
            if (scored.contains(note.note)) note.placement,
        ],
        target: asked,
        base: (written ?? layoutChord(placements, value)).headLeft,
      );
      paintMarks(
        canvas,
        placements: placements,
        colors: [for (final n in mine) n.color],
        value: value,
        x: x,
        centerY: stave.centerY,
        follow: written,
        accidentalColumns: columns,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OverlayPainter old) =>
      old.x != x ||
      !listEquals(old.notes, notes) ||
      !mapEquals(old.values, values) ||
      !mapEquals(old.target, target) ||
      !setEquals(old.scored, scored);
}
