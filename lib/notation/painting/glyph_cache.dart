import 'package:flutter/material.dart';

import '../layout/glyph.dart';
import '../layout/staff_style.dart';

/// Laid-out SMuFL glyphs, kept between frames.
///
/// v1 built and laid out a fresh [TextPainter] for every notehead, accidental,
/// clef and rest on every repaint — dozens of layouts a frame through a 340 ms
/// scroll. Glyphs are drawn at one fixed size, so the only thing that varies is
/// the colour, which makes them cheap to keep.
class GlyphCache {
  GlyphCache._();

  /// Colours change continuously while a column fades, so the cache is capped
  /// and dropped wholesale rather than growing without bound.
  static const _capacity = 512;

  static final _painters = <(MusicSymbol, int), TextPainter>{};

  static TextPainter _painterFor(MusicSymbol symbol, Color color) {
    final key = (symbol, color.toARGB32());
    if (_painters[key] case final cached?) return cached;
    if (_painters.length >= _capacity) _painters.clear();

    return _painters[key] = TextPainter(
      text: TextSpan(
        text: symbol.char,
        style: TextStyle(
          fontFamily: StaffMetrics.musicFace,
          fontSize: StaffMetrics.fontSize(staffScale),
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Draws [symbol] with its origin — the baseline at its left edge — at
  /// [anchorX] px, raised [offsetY] staff spaces above [centerY] (y up).
  static void paint(
    Canvas canvas,
    MusicSymbol symbol,
    double anchorX,
    double offsetY,
    double centerY,
    Color color,
  ) {
    final painter = _painterFor(symbol, color);
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final anchorY = centerY - offsetY * StaffMetrics.space * staffScale;
    painter.paint(canvas, Offset(anchorX, anchorY - baseline));
  }
}
