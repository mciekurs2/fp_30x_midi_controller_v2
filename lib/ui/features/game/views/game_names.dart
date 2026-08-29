import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../notation/widgets/staff_names.dart';
import '../view_models/game_controller.dart';

/// The names of what the round is asking for, wired to it — the counterpart to
/// [GameStaffView], which draws the same column on the staff.
class GameNames extends ConsumerWidget {
  const GameNames({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asked = ref.watch(
      gameControllerProvider.select(
        (game) => (score: game.staff, cursor: game.cursor),
      ),
    );
    return StaffNames(score: asked.score, cursor: asked.cursor);
  }
}
