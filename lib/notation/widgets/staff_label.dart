import 'package:flutter/material.dart';

import '../layout/staff_style.dart';

/// The type a staff's name is drawn in. Sized in staff units so it never
/// rescales with the notation; tweak here to restyle every mode's label.
TextStyle labelStyle(Color color) => TextStyle(
  fontFamily: 'JollyLodger',
  fontSize: labelSize * staffSpace,
  color: color,
  height: 1,
);

/// The caption under a name — the same face, smaller and dimmer, so it reads as
/// a note on the line above rather than a second label.
TextStyle captionStyle(Color color) => TextStyle(
  fontFamily: 'JollyLodger',
  fontSize: captionSize * staffSpace,
  color: color.withValues(alpha: 0.7),
  height: 1,
);

/// The key a round is in: the same face as the name of what to play, just
/// smaller. The HUD hangs it top-centre, between the score and the clock.
TextStyle keyNameStyle(Color color) => TextStyle(
  fontFamily: 'JollyLodger',
  fontSize: keyNameSize * staffSpace,
  color: color,
  height: 1,
);

/// A staff's name, centred across [width], arriving from the right and leaving
/// to the left — so the exercise reads as passing a fixed point.
///
/// It drives its own controllers instead of using an [AnimatedSwitcher] because
/// a switcher animates an interrupted child *backwards*: play the next note
/// before the current name has finished arriving and that name retreats to the
/// right it came from. Here the outgoing name is handed the exact offset and
/// opacity the incoming one had reached and carries on from there, so however
/// fast the notes come the motion only ever goes one way.
class SlidingLabel extends StatefulWidget {
  const SlidingLabel({
    super.key,
    required this.width,
    required this.slot,
    this.child,
  });

  /// The row's full width: what a name travels a fraction of, so `C4` and
  /// `[C4 E4 G4]` cover the same ground.
  final double width;

  /// What is on show; a change is what starts the hand-off.
  final Object? slot;

  /// The name itself, or `null` where there is nothing to name — which sends
  /// the name that was showing on its way and leaves the row empty.
  final Widget? child;

  @override
  State<SlidingLabel> createState() => _SlidingLabelState();
}

class _SlidingLabelState extends State<SlidingLabel>
    with TickerProviderStateMixin {
  static const _in = Curves.easeOutCubic;
  static const _out = Curves.easeInCubic;

  late final _enter = AnimationController(vsync: this, duration: labelIn);
  late final _leave = AnimationController(vsync: this, duration: labelOut);

  Widget? _leaving;

  /// Where the outgoing name was when it was handed over.
  double _fromX = 0;
  double _fromAlpha = 1;

  @override
  void initState() {
    super.initState();
    // The first name is already in place: nothing has moved yet.
    _enter.value = widget.child == null ? 0 : 1;
    _leave.value = 1;
  }

  @override
  void didUpdateWidget(SlidingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot == widget.slot) return;

    final reached = _in.transform(_enter.value);
    _fromX = labelSlide * (1 - reached);
    _fromAlpha = reached;
    _leaving = oldWidget.child;

    if (_leaving == null) {
      _leave.value = 1;
    } else {
      _leave.forward(from: 0);
    }
    if (widget.child == null) {
      _enter.value = 0;
    } else {
      _enter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaving = _leaving;
    return Stack(
      alignment: .center,
      children: [
        if (leaving != null)
          AnimatedBuilder(
            animation: _leave,
            builder: (context, _) {
              if (_leave.isCompleted) return const SizedBox.shrink();
              final t = _out.transform(_leave.value);
              return _at(
                _lerp(_fromX, -labelSlide, t),
                _fromAlpha * (1 - t),
                leaving,
              );
            },
          ),
        if (widget.child != null)
          AnimatedBuilder(
            animation: _enter,
            builder: (context, _) {
              final t = _in.transform(_enter.value);
              return _at(labelSlide * (1 - t), t, widget.child!);
            },
          ),
      ],
    );
  }

  /// [dx] is a fraction of [SlidingLabel.width], which the name is sized to.
  Widget _at(double dx, double alpha, Widget child) => FractionalTranslation(
    translation: Offset(dx, 0),
    child: Opacity(
      opacity: alpha.clamp(0, 1),
      child: SizedBox(width: widget.width, child: child),
    ),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
