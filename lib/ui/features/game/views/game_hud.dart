import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../domain/models/game_mode.dart';
import '../../../../notation/widgets/staff_label.dart';
import '../view_models/game_controller.dart';
import '../view_models/game_settings_controller.dart';
import '../view_models/game_state.dart';
import '../view_models/high_scores.dart';
import 'verdict_mark.dart';

/// How a changed value settles.
const _change = Duration(milliseconds: 400);

/// How far the old/new number slides, as a fraction of its own height.
const _rollShift = 1.0;

/// When the clock turns urgent.
const _urgent = Duration(seconds: 15);

/// Where the key name hangs, below the two readings' captions.
const _keyNameTop = 46.0;

const _tabular = [FontFeature.tabularFigures()];

/// Score and time left in the top corners; idle shows the next round's limit.
class GameHud extends ConsumerWidget {
  const GameHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = ref.watch(
      gameControllerProvider.select(
        (game) => (
          score: game.score,
          remaining: game.remaining,
          idle: game.phase == GamePhase.idle,
        ),
      ),
    );
    final settings = ref.watch(
      gameSettingsControllerProvider.select(
        (s) => (
          limit: s.timeLimit,
          scoreKey: s.highScoreKey,
          showsKey: s.mode.hasKnob(SettingKnob.chordKey),
          keyName: s.chordKey.name,
        ),
      ),
    );

    final remaining = round.idle ? settings.limit : round.remaining;
    final scoreKey = settings.scoreKey;
    final topScores = scoreKey == null
        ? const <int>[]
        : ref.watch(highScoresProvider.select((s) => s[scoreKey])) ??
              const <int>[];

    return Stack(
      children: [
        // Both readings are flexible: at the app's 1.5x text scale a score with
        // its saved top three beside it runs into the clock on a 360 dp phone.
        Row(
          crossAxisAlignment: .start,
          children: [
            Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                _Reading(
                  caption: 'Score',
                  value: '${round.score}',
                  alignment: .start,
                  animate: true,
                  topScores: topScores,
                ),
                const Padding(
                  padding: .only(top: 32),
                  child: VerdictMark(),
                ),
              ],
            ),
            Spacer(),
            _Reading(
              caption: 'Time',
              value: _formatTime(remaining),
              alignment: .end,
              color: remaining != null && remaining <= _urgent
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ],
        ),
        // The key a round is played in reads once and holds, so it lives up
        // here rather than with the chord name that changes under the staff.
        // Positioned, so it neither widens the HUD nor stretches it down.
        if (settings.showsKey)
          Positioned(
            top: _keyNameTop,
            left: 0,
            right: 0,
            child: Text(
              settings.keyName,
              textAlign: .center,
              // No text scaling: sized in staff units, like the staff's names.
              textScaler: TextScaler.noScaling,
              style: labelStyle(Theme.of(context).colorScheme.onSurface),
            ),
          ),
      ],
    );
  }

  static String _formatTime(Duration? remaining) {
    if (remaining == null) return 'Infinite';
    final seconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.caption,
    required this.value,
    required this.alignment,
    this.color,
    this.animate = false,
    this.topScores = const [],
  });

  final String caption;
  final String value;
  final CrossAxisAlignment alignment;
  final Color? color;

  /// Rolls the value on change (the score only; the clock stays still).
  final bool animate;

  /// Highest saved scores for this bucket, listed faint beside the caption.
  final List<int> topScores;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.displaySmall?.copyWith(color: color, fontFeatures: _tabular);

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: .min,
      children: [
        _Caption(caption: caption, topScores: topScores),
        if (animate)
          AnimatedSwitcher(
            duration: _change,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: _rollTransition,
            // Keep the number pinned to the reading's side as it rolls.
            layoutBuilder: (current, previous) => Stack(
              alignment: alignment == CrossAxisAlignment.end
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Text(value, key: ValueKey(value), style: style),
          )
        else
          Text(value, style: style),
      ],
    );
  }
}

/// The caption, with the saved scores trailing it in brackets — `Score (55, 34,
/// 22)` — fainter than the caption so they read as a footnote to it.
class _Caption extends StatelessWidget {
  const _Caption({required this.caption, required this.topScores});

  final String caption;
  final List<int> topScores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (topScores.isEmpty) {
      return Text(caption, style: style, maxLines: 1, overflow: .ellipsis);
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: caption),
          TextSpan(
            text: ' (${topScores.join(', ')})',
            style: TextStyle(
              color: style?.color?.withValues(alpha: 0.5),
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: .ellipsis,
    );
  }
}

/// Rolls a changed number upward: the new value slides in from below while the
/// old slides out the top, each fading.
Widget _rollTransition(Widget child, Animation<double> animation) {
  return DualTransitionBuilder(
    animation: animation,
    forwardBuilder: (context, animation, child) => ClipRect(
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, _rollShift),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    ),
    reverseBuilder: (context, animation, child) => ClipRect(
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.0).animate(animation),
        child: SlideTransition(
          position: Tween(
            begin: Offset.zero,
            end: const Offset(0, -_rollShift),
          ).animate(animation),
          child: child,
        ),
      ),
    ),
    child: child,
  );
}
