import 'package:flutter/material.dart';

import '../../domain/models/note_value.dart';
import '../layout/score_layout.dart';
import '../layout/staff_style.dart';
import '../model/clef.dart';
import '../model/score.dart';
import '../model/spelling.dart';
import '../model/staff_placement.dart';
import '../painting/score_painter.dart';

/// How long a note takes to settle onto the staff — reads as settling, not lag.
const _entry = Duration(milliseconds: 300);
const _exit = Duration(milliseconds: 200);

/// How far a note slides as it drops in / out, as a fraction of the scale.
const _slide = 0.06;

/// Held keys sit just back from the written notes, so the two read apart where
/// one lands on the other.
const _playedOpacity = 0.8;

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
    this.color,
    this.playedColor,
    this.correctColor,
    this.scale = 1,
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

  final Color? color;
  final Color? playedColor;
  final Color? correctColor;

  /// How large the notation draws, 1.0 being its own size.
  ///
  /// The staff is laid out in a box scaled *up* by the inverse and painted back
  /// down into the real one, so glyphs, staff spacing, margins and the columns
  /// that fit all shrink by the same factor — rather than the notation keeping
  /// its size and simply losing room. Sizing anything here in pixels instead
  /// would drift from [staffSpace], which the whole notation is a fraction of.
  final double scale;

  @override
  State<StaffView> createState() => _StaffViewState();
}

/// How one held key is written, remembered for as long as it is down.
typedef _Writing = ({StaffPlacement placement, int stave});

/// How a target was written, kept after it has been replaced.
typedef _Written = ({Clef clef, Spelling spelling, ScoreColumn? column});

class _StaffViewState extends State<StaffView> {
  ScoreMeasure? _measure;

  /// A key keeps the writing it was first drawn with until it is released, so a
  /// scored note does not flip spelling — B3 to C♭4, a staff step — the moment
  /// the next target is dealt. A key the *current* column asks for is
  /// re-recorded, which is what lets a key held from a flat chord into a sharp
  /// one that wants it be rewritten rather than keep the old spelling.
  final _writings = <int, _Writing>{};

  ScoreMeasure get _scoreMeasure => _measure ??= ScoreMeasure(widget.score);

  /// How the target before this one was written.
  ///
  /// A key that scores keeps the clef and spelling of the target it answered —
  /// the green note holds the staff position it was played at rather than
  /// jumping an octave or a clef the moment the next target is dealt. This is
  /// the only place that context survives: grading deals the next target in the
  /// same event as the press, so the staff never draws a frame with the key
  /// down under the target it was answering.
  _Written? _lastTarget;

  @override
  void didUpdateWidget(StaffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.score, widget.score)) return;
    _measure = null;
    final old = oldWidget.score;
    // Only a centred score deals a fresh target under a standing hand. A
    // flowing one writes its scored keys against the column they were struck
    // at, which carries the same context already.
    _lastTarget = old.columns.length == 1
        ? (
            clef: old.staves.first.clef,
            spelling: old.spelling,
            column: old.columns.first,
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.onSurface;
    final playedColor = widget.playedColor ?? theme.colorScheme.primary;
    final correctColor = widget.correctColor ?? theme.colorScheme.tertiary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest / widget.scale;
        final target = widget.cursor.toDouble();
        final snap =
            (target - _lastPosition).abs() > snapDistance ||
            widget.score.columns.length <= 1;
        _lastPosition = target;

        final staff = TweenAnimationBuilder<double>(
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
        if (widget.scale == 1) return staff;
        // The staff is built at [size] — larger than the box it is given — so
        // it needs constraints to match before the transform brings it back
        // inside. A plain child would be clipped to the box by the Stack.
        return Transform.scale(
          scale: widget.scale,
          child: OverflowBox(
            minWidth: size.width,
            maxWidth: size.width,
            minHeight: size.height,
            maxHeight: size.height,
            child: staff,
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
            key: ValueKey(_clefSignature(layout)),
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
        transitionBuilder: drop
            ? _dropTransition
            : AnimatedSwitcher.defaultTransitionBuilder,
        child: child,
      );

  /// A flowing score moves by scrolling, so its columns repaint in place; a
  /// centred one has nowhere to scroll, so its note drops in instead.
  Widget _columns(ScoreLayout layout, Size size, Color color) {
    final painter = CustomPaint(
      key: ValueKey(
        layout.isEmpty
            ? ''
            : _columnSignature(
                widget.score.columns[layout.base.clamp(0, layout.last)],
              ),
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

  /// The keys the player has down, drawn over the column they answer.
  ///
  /// A centred score draws them as one layer, the way v1 did: the live attempt
  /// and whatever already scored sit on the same column, so they drop in and
  /// out together and a key that turns from wrong to right only changes colour.
  /// A flowing score keeps them apart — the scored ones are pinned to where
  /// they were struck while the rest of the music scrolls past them — and, as
  /// in v1, neither layer animates: the scroll is the movement.
  List<Widget> _overlays(
    ScoreLayout layout,
    ScoreMeasure measure,
    Size size,
    Color playedColor,
    Color correctColor,
  ) {
    _writings.removeWhere((note, _) => !_isHeld(note));
    if (layout.isEmpty) return const [];

    final current = layout.base.clamp(layout.first, layout.last);
    final currentColumn = widget.score.columns[current];
    Color tint(int note) =>
        widget.correct.contains(note) ? correctColor : playedColor;

    if (layout.alignment == ScoreAlignment.centered) {
      final notes = _resolve(
        {...widget.played, ...widget.scored},
        currentColumn,
        layout,
        tint,
      );
      final values = _valuesFor(currentColumn, layout);
      return [
        Opacity(
          opacity: _playedOpacity,
          child: Stack(
            fit: .expand,
            children: [
              // Its own switcher per stave, so a note changing under an
              // unchanged clef does not fade the clef along with it.
              for (final stave in layout.staves)
                _switcher(
                  child: _extraClef(
                    _extraClefNotes(layout, notes)[stave.index],
                    stave,
                    size,
                  ),
                ),
              _switcher(
                drop: true,
                child: notes.isEmpty
                    ? const SizedBox.shrink(key: ValueKey('no-held'))
                    : CustomPaint(
                        key: ValueKey(_heldSignature(notes, values)),
                        size: size,
                        painter: OverlayPainter(
                          notes: notes,
                          layout: layout,
                          values: values,
                          target: _placementsFor(currentColumn, layout),
                          scored: widget.scored,
                          x: layout.columnX(current),
                          clip: false,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ];
    }

    final live = _resolve(widget.played, currentColumn, layout, tint);
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
      Opacity(
        opacity: _playedOpacity,
        child: Stack(
          fit: .expand,
          children: [
            for (final stave in layout.staves)
              _extraClef(
                _extraClefNotes(layout, [...live, ...pinned])[stave.index],
                stave,
                size,
              ),
            CustomPaint(
              size: size,
              painter: OverlayPainter(
                notes: live,
                layout: layout,
                values: _valuesFor(currentColumn, layout),
                target: _placementsFor(currentColumn, layout),
                x: layout.columnX(current),
                clip: true,
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
                clip: true,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// A held key still written in a clef the stave no longer carries brings that
  /// clef along, so there is something to read it against.
  ///
  /// It happens when a key scored under one target and is held into the next:
  /// it keeps the writing it was struck with, and the new target's clef may not
  /// be the same one. Tinted by the lowest key carrying it — the one picked out
  /// here, per stave.
  Map<int, HeldNote> _extraClefNotes(ScoreLayout layout, List<HeldNote> notes) {
    final extra = <int, HeldNote>{};
    for (final note in notes) {
      if (note.placement.clef == layout.staves[note.stave].clef) continue;
      final lowest = extra[note.stave];
      if (lowest == null || note.note < lowest.note) extra[note.stave] = note;
    }
    return extra;
  }

  Widget _extraClef(HeldNote? note, StaveLayout stave, Size size) =>
      note == null
      ? SizedBox.shrink(key: ValueKey('no-extra-clef-${stave.index}'))
      : CustomPaint(
          // Colour is left out on purpose: a key turning from wrong to right
          // repaints its clef rather than fading in a new one.
          key: ValueKey(
            'extra-clef-${stave.index}:${note.placement.clef.name}',
          ),
          size: size,
          painter: ClefPainter(
            staves: [
              (
                clef: note.placement.clef,
                centerY: stave.centerY,
                index: stave.index,
              ),
            ],
            color: note.color,
          ),
        );

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
        for (final note
            in column.voices.elementAtOrNull(stave.index)?.notes ??
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
      final stave = staveForNote(layout, note, column);
      // A key the column asks for is (re)written its way — held on from a flat
      // chord into a sharp one that wants the same key, it would otherwise keep
      // its old spelling and sit a step off the notehead it is answering.
      final asked = column.midiNotes.contains(note);
      final writing = asked
          ? _write(note, stave, widget.score.spelling, column, stave.clef)
          : _writings[note] ??
                _fromLastTarget(note, stave) ??
                _write(note, stave, widget.score.spelling, column, stave.clef);
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

  _Writing _write(
    int note,
    StaveLayout stave,
    Spelling spelling,
    ScoreColumn? column,
    Clef clef,
  ) => (
    placement: placeHeldNote(note, clef, column, stave.index, spelling),
    stave: stave.index,
  );

  /// A key that has already scored, written the way the target it answered was.
  _Writing? _fromLastTarget(int note, StaveLayout stave) {
    final last = _lastTarget;
    if (last == null || !widget.scored.contains(note)) return null;
    return _write(note, stave, last.spelling, last.column, last.clef);
  }

}

/// The keys the entry animations are switched on.
///
/// [AnimatedSwitcher] compares child keys with `==`, and a Dart `List` is equal
/// only to itself — so a key built from one is never equal to the last frame's,
/// and the layer animates in again on every rebuild. Since a keypress rebuilds
/// the staff, that re-drops the written notes on every press, right or wrong.
/// Naming the content instead means a layer animates when what it draws
/// changes, and repaints in place when it does not.
String _clefSignature(ScoreLayout layout) =>
    [for (final stave in layout.staves) stave.clef.name].join(',');

String _columnSignature(ScoreColumn column) => [
  for (final voice in column.voices)
    if (voice == null)
      '-'
    else
      '${voice.value.name}${voice.dotted ? '.' : ''}'
          ':${[for (final note in voice.notes) _noteSignature(note)].join(' ')}',
].join('|');

String _heldSignature(List<HeldNote> notes, Map<int, NoteValue> values) => [
  [for (final note in notes) note.note]..sort(),
  [for (final entry in values.entries) '${entry.key}${entry.value.name}']
    ..sort(),
].join('/');

String _noteSignature(ScoreNote note) =>
    '${note.midi}/${note.letter}/${note.octave}/${note.drawn?.name}';

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
