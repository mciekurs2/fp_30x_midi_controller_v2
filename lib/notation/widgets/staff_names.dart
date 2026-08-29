import 'package:flutter/material.dart';

import '../model/score.dart';
import 'staff_label.dart';

/// What the cursor's column asks for, named: one row per stave, the keys to
/// press and under them the chord they spell.
///
/// The caller decides where it hangs, but not how tall it is: the block is
/// always **one row** tall and its rows hang downward from that top edge. Sized
/// to its rows instead, a second stave grew the block upward — it is anchored
/// to the bottom of the screen — and put the names over the staff they name.
///
/// Each row also holds itself open behind an invisible copy of the type it
/// draws, so a stave with nothing to name does not close the gap and jog the
/// row under it as the cursor advances.
class StaffNames extends StatelessWidget {
  const StaffNames({
    super.key,
    required this.score,
    this.cursor = 0,
    this.turn = 0,
    this.color,
  });

  final Score score;

  /// Which column is being asked for. Read straight, not through the staff's
  /// animated scroll position — that only reaches the new column when the
  /// 340 ms scroll lands, which left the name a whole scroll behind the note
  /// it names.
  final int cursor;

  /// Which ask this is, counting up as the round deals them.
  ///
  /// The name hands over when what it names changes, and two asks running can
  /// be the same keys — a chord struck twice, or the same note dealt again —
  /// which by name alone is no change at all, so the label sat still where the
  /// staff had plainly moved on. Centred modes never move their cursor, so this
  /// is the only thing that separates one ask from the next there.
  final int turn;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (score.isEmpty) return const SizedBox.shrink();
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    final column = score.columns[cursor.clamp(0, score.columns.length - 1)];

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        clipBehavior: .none,
        children: [
          // One row of the same type, invisible: what the block measures as.
          // Full width, because the rows are positioned to the block's edges —
          // sized to the type alone it was one space wide and every name wrapped
          // a character to a line.
          SizedBox(
            width: constraints.maxWidth,
            child: Opacity(
              opacity: 0,
              child: _rowType(' ', score.hasCaptions, tint),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: .min,
              children: [
                for (var i = 0; i < score.staves.length; i++)
                  _NameRow(
                    width: constraints.maxWidth,
                    voice: column.voices.elementAtOrNull(i),
                    captioned: score.hasCaptions,
                    color: tint,
                    ask: (cursor, turn),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One stave's name row: what to press, and under it what it spells.
class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.width,
    required this.voice,
    required this.captioned,
    required this.color,
    required this.ask,
  });

  final double width;
  final ScoreVoice? voice;
  final bool captioned;
  final Color color;

  /// Which ask this row is naming, so the same name asked again still slides.
  final Object ask;

  @override
  Widget build(BuildContext context) {
    final label = voice?.label;
    final caption = voice?.caption;
    return Stack(
      // Top, not centre: a row grows downward from its own top edge, so
      // whatever it holds never pushes the row above it up.
      alignment: .topCenter,
      children: [
        // An invisible copy of the same type, so the row keeps its height with
        // nothing to name rather than collapsing under the row above it.
        Opacity(opacity: 0, child: _rowType(' ', captioned, color)),
        SlidingLabel(
          width: width,
          slot: (ask, label, caption),
          child: label == null
              ? null
              : _rowType(label, captioned, color, caption: caption ?? ''),
        ),
      ],
    );
  }
}

/// The type one row draws: the name and, where the score captions its chords,
/// the chord it spells beside it — bracketed the way the name itself is, so the
/// pair reads as one line. Measuring and drawing both go through this, so the
/// height reserved is the height actually used.
Widget _rowType(
  String label,
  bool captioned,
  Color color, {
  String caption = ' ',
}) =>
    // One line always: the block reserves the height of exactly one, so a name
    // long enough to wrap would spill over the row below it. `[B3 D4 E4 G4]`
    // beside the chord it spells is wide enough to on a 360 dp phone, so it
    // shrinks to fit instead.
    FittedBox(
      fit: .scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label, style: labelStyle(color)),
            // One span, so the two sit on a shared baseline whatever their
            // sizes.
            if (captioned && caption.isNotEmpty)
              TextSpan(
                text: '$_captionGap[$caption]',
                style: captionStyle(color),
              ),
          ],
        ),
        textAlign: .center,
        maxLines: 1,
        // No text scaling: names are sized in staff units, like glyphs.
        textScaler: TextScaler.noScaling,
      ),
    );

/// Between the name and the chord it spells.
const _captionGap = '  ';
