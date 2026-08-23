import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../view_models/game_controller.dart';

/// Starts a round, or stops the one in progress.
class PlayButton extends ConsumerWidget {
  const PlayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(
      gameControllerProvider.select((game) => game.isRunning),
    );

    return FilledButton.tonalIcon(
      onPressed: () => ref.read(gameControllerProvider.notifier).toggle(),
      icon: Icon(
        isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
        size: 32,
      ),
      label: Text(isRunning ? 'Stop' : 'Play', style: .new(fontSize: 16)),
    );
  }
}
