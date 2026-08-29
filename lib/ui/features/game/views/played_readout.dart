import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../domain/models/chord_identifier.dart';
import '../../../../notation/widgets/layer_switcher.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/game_controller.dart';
import '../view_models/note_source.dart';

/// How much bigger than the theme's headline the readout is drawn, matching the
/// staff's own labels.
const _enlarge = 1.2;

/// Names what is under the hands right now — one key, or the chord the held
/// keys spell, in [successColor] once the round counts every one of them as
/// right — the same green the staff tints those keys.
///
/// It takes the name from the hands, not the round: keys that have already
/// scored still count, since dropping them would make the name flicker as a
/// chord is graded. The colour is the round's word on those same keys, so a
/// name the game is not grading — anything held while idle — stays the accent.
class PlayedReadout extends ConsumerWidget {
  const PlayedReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The whole hand, not the round's view of it: modes that grade a subset
    // (single note takes only the lowest key) would otherwise colour a name
    // amber while one of the keys it spells is wrong.
    final held = ref.watch(noteSourceProvider).keys;
    // `correct` is carried through `copyWith` by identity, so watching it keeps
    // the clock's every-second tick off this widget's rebuild path.
    final correct = ref.watch(
      gameControllerProvider.select((game) => game.correct),
    );

    final name = playedName(held);
    final isHit = held.isNotEmpty && correct.containsAll(held);
    final theme = Theme.of(context);
    final headline = theme.textTheme.headlineSmall;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCirc,
      switchOutCurve: Curves.easeInCubic,
      // Never the default builder: the readout empties between presses, so
      // `nothing` comes back under a key it has worn before.
      transitionBuilder: fadeLayer,
      child: name == null
          ? const SizedBox.shrink(key: ValueKey('nothing'))
          : Text(
              name,
              key: ValueKey(name),
              textAlign: .center,
              maxLines: 1,
              overflow: .ellipsis,
              // Colour is deliberately out of the switcher key: a name that
              // turns from wrong to right recolours in place instead of
              // sliding in again.
              style: headline?.copyWith(
                color: isHit ? successColor : theme.colorScheme.primary,
                fontSize: (headline.fontSize ?? 28) * _enlarge,
              ),
            ),
    );
  }
}
