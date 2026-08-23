import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../domain/models/chord_identifier.dart';
import '../view_models/note_source.dart';

/// How much bigger than the theme's headline the readout is drawn, matching the
/// staff's own labels.
const _enlarge = 1.2;

/// Names what is under the hands right now — one key, or the chord the held
/// keys spell. It reads the hands, not the round: keys that have already scored
/// still count, since dropping them would make the name flicker as a chord is
/// graded.
class PlayedReadout extends ConsumerWidget {
  const PlayedReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selecting on the name, not the map, keeps this off the rebuild path for
    // presses that do not change what the chord is called.
    final name = ref.watch(
      noteSourceProvider.select((held) => playedName(held.keys)),
    );
    final theme = Theme.of(context);
    final headline = theme.textTheme.headlineMedium;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCirc,
      switchOutCurve: Curves.easeInCubic,
      child: name == null
          ? const SizedBox.shrink(key: ValueKey('nothing'))
          : Text(
              name,
              key: ValueKey(name),
              textAlign: .center,
              maxLines: 1,
              overflow: .ellipsis,
              style: headline?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: (headline.fontSize ?? 28) * _enlarge,
              ),
            ),
    );
  }
}
