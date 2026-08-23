import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../view_models/game_controller.dart';
import '../view_models/game_state.dart';

/// Fade in / out timings, matching the note entry and exit so the verdict reads
/// as part of the same feedback.
const _fadeIn = Duration(milliseconds: 300);
const _fadeOut = Duration(milliseconds: 200);

/// Eases the fade-in (opacity, scale and shake) for both marks.
const _enterCurve = Curves.easeOutBack;

/// How long the mark sits at full presence before fading out.
const _hold = Duration(milliseconds: 400);

const _crossSize = 52.0;
const _starSize = 42.0;

/// How much bigger the star grows at full presence.
const _starPop = 0.5;

/// The cross's horizontal wiggle: amplitude in px, one swing during the fade-in.
const _shakeAmplitude = 5.0;

/// A momentary mark on each graded press: a star that pops for a hit, a cross
/// that shakes for a miss. Both fade in, hold, then fade out.
///
/// It lives under the score rather than over the staff, where it used to cover
/// the very notes it was grading.
class VerdictMark extends ConsumerStatefulWidget {
  const VerdictMark({super.key});

  @override
  ConsumerState<VerdictMark> createState() => _VerdictMarkState();
}

class _VerdictMarkState extends ConsumerState<VerdictMark>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _fadeIn,
    reverseDuration: _fadeOut,
  )..addStatusListener(_onStatus);

  /// Held so the mark keeps its shape through the fade-out.
  Verdict? _shown;
  int? _lastToken;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    // Start from the current tick, so the first grade of the session counts as
    // a change rather than being swallowed as the initial value.
    final game = ref.read(gameControllerProvider);
    _lastToken = game.hits + game.misses;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(_hold, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onGrade(int token, Verdict? verdict) {
    final previous = _lastToken;
    _lastToken = token;
    // Skip the first build; only fire on an actual new grade.
    if (previous == null || token == previous || verdict == null) return;
    _holdTimer?.cancel();
    setState(() => _shown = verdict);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // `hits + misses` ticks with every grade, so a repeat still re-fires.
    ref.listen(
      gameControllerProvider.select(
        (game) => (game.hits + game.misses, game.verdict),
      ),
      (_, next) => _onGrade(next.$1, next.$2),
    );

    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final verdict = _shown;
        if (verdict == null || _controller.value == 0) {
          return const SizedBox.shrink();
        }

        // Curve the fade-in; the fade-out stays linear.
        final entering = _controller.status == AnimationStatus.forward;
        final v = entering
            ? _enterCurve.transform(_controller.value)
            : _controller.value;

        final isHit = verdict == Verdict.hit;
        // One swing, and only while fading in — so it shakes just once.
        final dx = (!isHit && entering)
            ? math.sin(v * 2 * math.pi) * _shakeAmplitude
            : 0.0;

        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx - 10, 0),
            child: Transform.scale(
              scale: isHit ? 1 + _starPop * v : 1,
              child: Icon(
                isHit ? Icons.star_rounded : Icons.close_rounded,
                size: isHit ? _starSize : _crossSize,
                color: isHit ? hitColor : scheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}
