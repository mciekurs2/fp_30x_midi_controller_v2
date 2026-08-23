import 'package:flutter/material.dart';

import '../../domain/models/note_value.dart';
import '../layout/score_layout.dart';
import '../layout/staff_style.dart';
import '../model/score.dart';
import '../model/staff_placement.dart';
import '../painting/score_painter.dart';
import 'staff_label.dart';

/// How long a note takes to settle onto the staff — reads as settling, not lag.
const _entry = Duration(milliseconds: 300);
const _exit = Duration(milliseconds: 200);

/// How far a note slides as it drops in / out, as a fraction of the scale.
const _slide = 0.06;

/// The one staff. It draws a [Score] — a single note, a chord, or a piece of
/// sheet music — and the player's held keys over it.
///
/// A one-column score is centred and its notes drop in as they change; a longer
/// one flows left to right and scrolls under the cursor. Both go through the
/// same layout and the same painting primitives, so notation is identical in
/// size and weight whichever exercise is on screen.
class StaffView extends StatefulWidget {
  const StaffView({
    super.key,
    required this.score,
    this.cursor = 0,
    this.played = const {},
    this.correct = const {},
    this.scored = const {},
    this.scoredColumn = 0,
    this.readout,
    this.color,
    this.playedColor,
    this.correctColor,
  });

  final Score score;

  /// Which column is being asked for.
  final int cursor;

  /// The keys currently held, drawn over the cursor's column.
  final Set<int> played;

  /// Which of [played] the round counts as right. Passed in rather than derived
  /// here so the staff and the grading always agree on what "correct" means.
  final Set<int> correct;

  /// Keys that already scored and have not been let go of. They are pinned to
  /// the column they were struck at, so they hold their spot instead of sliding
  /// with the score or snapping forward when the scroll lands.
  final Set<int> scored;
  final int scoredColumn;

  /// Hung above the system, where there is room on a phone — the names under it
  /// already fill the space below.
  final Widget? readout;

  final Color? color;
  final Color? playedColor;
  final Color? correctColor;

  @override
  State<StaffView> createState() => _StaffViewState();
}

/// How one held key is written, remembered for as long as it is down.
typedef _Writing = ({StaffPlacement placement, int stave, NoteValue value});

class _StaffViewState extends State<StaffView> {
  ScoreMeasure? _measure;

  /// A key keeps the writing it was first drawn with until it is released, so a
  /// scored note does not flip spelling — B3 to C♭4, a staff step — the moment
  /// the next target is dealt. A key the *current* column asks for is
  /// re-recorded, which is what lets a key held from a flat chord into a sharp
  /// one that wants it be rewritten rather than keep the old spelling.
  final _writings = <int, _Writing>{};

  ScoreMeasure get _scoreMeasure =>
      _measure ??= ScoreMeasure(widget.score);

  @override
  void didUpdateWidget(StaffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.score, widget.score)) _measure = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.onSurface;
    final playedColor = widget.playedColor ?? theme.colorScheme.primary;
    final correctColor = widget.correctColor ?? theme.colorScheme.tertiary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final target = widget.cursor.toDouble();
        final snap =
            (target - _lastPosition).abs() > snapDistance ||
            widget.score.columns.length <= 1;
        _lastPosition = target;

        return TweenAnimationBuilder<double>(
          // Only `end` is compared build to build, so restating `begin` here is
          // read on the first frame alone; the tween carries on from wherever
          // it had reached.
          tween: Tween(begin: target, end: target),
          duration: snap ? Duration.zero : scrollDuration,
          curve: Curves.easeInOutCubic,
          builder: (context, position, _) => _build(
            size: size,
            position: position,
            color: color,
            playedColor: playedColor,
            correctColor: correctColor,
          ),
        );
      },
    );
  }

  double _lastPosition = 0;

  Widget _build({
    required Size size,
    required double position,
    required Color color,
    required Color playedColor,
    required Color correctColor,
  }) {
    final measure = _scoreMeasure;
    final layout = layoutScore(
      measure,
      position: position,
      width: size.width,
      height: size.height,
    );

    return Stack(
      fit: .expand,
      children: [
        CustomPaint(
          size: size,
          painter: StaffLinesPainter(layout: layout, color: color),
        ),
        _switcher(
          child: CustomPaint(
            key: ValueKey([for (final s in layout.staves) s.clef]),
            size: size,
            painter: ClefPainter(staves: layout.staves, color: color),
          ),
        ),
        _switcher(
          child: widget.score.drawnSignature == null
              ? const SizedBox.shrink(key: ValueKey('no-signature'))
              : CustomPaint(
                  key: ValueKey(widget.score.signatureKey),
                  size: size,
                  painter: SignaturePainter(
                    staves: layout.staves,
                    musicKey: widget.score.signatureKey!,
                    color: color,
                  ),
                ),
        ),
        _columns(layout, size, color),
        ..._overlays(layout, measure, size, playedColor, correctColor),
        ..._labelRows(layout, size, color),
        _readoutSlot(layout, size),
      ],
    );
  }

  /// Crossfades a layer when what it draws changes; unchanged, it repaints in
  /// place rather than re-animating.
  Widget _switcher({required Widget child, bool drop = false}) =>
      AnimatedSwitcher(
        duration: _entry,
        reverseDuration: _exit,
        switchInCurve: Curves.easeOutCirc,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: drop ? _dropTransition : AnimatedSwitcher.defaultTransitionBuilder,
        child: child,
      );

  /// A flowing score moves by scrolling, so its columns repaint in place; a
  /// centred one has nowhere to scroll, so its note drops in instead.
  Widget _columns(ScoreLayout layout, Size size, Color color) {
    final painter = CustomPaint(
      key: ValueKey(
        layout.isEmpty
            ? const []
            : widget.score.columns[layout.base.clamp(0, layout.last)].midiNotes,
      ),
      size: size,
      painter: ColumnsPainter(
        score: widget.score,
        layout: layout,
        color: color,
      ),
    );
    if (layout.alignment == ScoreAlignment.flowing) return painter;
    return _switcher(
      drop: true,
      child: widget.score.isEmpty
          ? const SizedBox.shrink(key: ValueKey('no-note'))
          : painter,
    );
  }

  /// Two overlays: the live attempt on the cursor's column, and — pinned to
  /// where they were struck — the keys that already scored.
  List<Widget> _overlays(
    ScoreLayout layout,
    ScoreMeasure measure,
    Size size,
    Color playedColor,
    Color correctColor,
  ) {
    if (layout.isEmpty) {
      _writings.removeWhere((note, _) => !_isHeld(note));
      return const [];
    }
    final current = layout.base.clamp(layout.first, layout.last);
    final currentColumn = widget.score.columns[current];

    _writings.removeWhere((note, _) => !_isHeld(note));

    final live = _resolve(
      widget.played,
      currentColumn,
      layout,
      (note) => widget.correct.contains(note) ? correctColor : playedColor,
    );
    final pinnedIndex = widget.scoredColumn.clamp(
      0,
      widget.score.columns.length - 1,
    );
    final pinnedColumn = widget.score.columns[pinnedIndex];
    final pinned = _resolve(
      widget.scored,
      pinnedColumn,
      layout,
      (_) => correctColor,
    );

    return [
      CustomPaint(
        size: size,
        painter: OverlayPainter(
          notes: live,
          layout: layout,
          values: _valuesFor(currentColumn, layout),
          target: _placementsFor(currentColumn, layout),
          x: layout.columnX(current),
          clip: layout.alignment == ScoreAlignment.flowing,
        ),
      ),
      CustomPaint(
        size: size,
        painter: OverlayPainter(
          notes: pinned,
          layout: layout,
          values: _valuesFor(pinnedColumn, layout),
          target: _placementsFor(pinnedColumn, layout),
          x: layout.lead + measure.extents[pinnedIndex].left * staffSpace,
          clip: layout.alignment == ScoreAlignment.flowing,
        ),
      ),
    ];
  }

  bool _isHeld(int note) =>
      widget.played.contains(note) || widget.scored.contains(note);

  Map<int, NoteValue> _valuesFor(ScoreColumn column, ScoreLayout layout) => {
    for (final stave in layout.staves)
      stave.index: heldNoteValue(column, stave.index),
  };

  /// What each stave is asking for, so the overlay can be fitted around it.
  Map<int, List<StaffPlacement>> _placementsFor(
    ScoreColumn column,
    ScoreLayout layout,
  ) => {
    for (final stave in layout.staves)
      stave.index: [
        for (final note in column.voices.elementAtOrNull(stave.index)?.notes ??
            const <ScoreNote>[])
          note.placeOn(stave.clef, widget.score.spelling),
      ],
  };

  List<HeldNote> _resolve(
    Set<int> notes,
    ScoreColumn column,
    ScoreLayout layout,
    Color Function(int note) tint,
  ) {
    final resolved = <HeldNote>[];
    for (final note in notes) {
      final stave = staveForNote(layout, note);
      // A key the column asks for is (re)written its way; anything else keeps
      // whatever it was first drawn as.
      final remembered = column.midiNotes.contains(note)
          ? null
          : _writings[note];
      final writing =
          remembered ??
          (
            placement: placeHeldNote(
              note,
              stave.clef,
              column,
              stave.index,
              widget.score.spelling,
            ),
            stave: stave.index,
            value: heldNoteValue(column, stave.index),
          );
      _writings[note] = writing;
      resolved.add((
        note: note,
        placement: writing.placement,
        stave: writing.stave,
        color: tint(note),
      ));
    }
    return resolved;
  }

  /// One name row per stave, below the system: the keys to press and, under
  /// them, the chord they spell. Following the notes leaves no room on a phone,
  /// so each row shows only the cursor's column, sliding as it advances.
  List<Widget> _labelRows(ScoreLayout layout, Size size, Color color) {
    if (layout.isEmpty) return const [];
    final column =
        widget.score.columns[layout.base.clamp(layout.first, layout.last)];
    final rowHeight =
        (labelSize + (widget.score.hasCaptions ? captionSize : 0)) * staffSpace;
    final top = layout.bottomStaveY + layout.labelDropSpaces * staffSpace;

    return [
      for (final stave in layout.staves)
        Positioned(
          top: top + stave.index * rowHeight,
          left: 0,
          right: 0,
          child: _NameRow(
            width: size.width,
            voice: column.voices.elementAtOrNull(stave.index),
            captioned: widget.score.hasCaptions,
            color: color,
          ),
        ),
    ];
  }

  Widget _readoutSlot(ScoreLayout layout, Size size) => Positioned(
    bottom: size.height - layout.topStaveY + playedRise * staffSpace,
    left: 16,
    right: 16,
    child: widget.readout ?? const SizedBox.shrink(),
  );
}

/// One stave's name row: what to press, and under it what it spells.
class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.width,
    required this.voice,
    required this.captioned,
    required this.color,
  });

  final double width;
  final ScoreVoice? voice;
  final bool captioned;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = voice?.label;
    final caption = voice?.caption;
    return SlidingLabel(
      width: width,
      slot: (label, caption),
      child: label == null
          ? null
          : Column(
              mainAxisSize: .min,
              children: [
                // No text scaling: names are sized in staff units, like glyphs.
                Text(
                  label,
                  textAlign: .center,
                  textScaler: TextScaler.noScaling,
                  style: labelStyle(color),
                ),
                if (captioned)
                  Text(
                    caption ?? '',
                    textAlign: .center,
                    textScaler: TextScaler.noScaling,
                    style: captionStyle(color),
                  ),
              ],
            ),
    );
  }
}

/// In from just above, out to just below, each with a fade.
Widget _dropTransition(Widget child, Animation<double> animation) {
  return DualTransitionBuilder(
    animation: animation,
    forwardBuilder: (context, animation, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -_slide),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    reverseBuilder: (context, animation, child) => FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.0).animate(animation),
      child: SlideTransition(
        position: Tween(
          begin: Offset.zero,
          end: const Offset(0, _slide),
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  );
}
