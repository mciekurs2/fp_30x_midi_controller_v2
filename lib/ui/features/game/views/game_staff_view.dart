import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../notation/widgets/staff_view.dart';
import '../view_models/game_controller.dart';

/// The staff, wired to the round.
///
/// Every mode-specific decision — which score, which column, which held keys
/// read as the attempt and which of them count — is resolved by
/// [GameController], so there is nothing to branch on here. v1's equivalent was
/// a hundred lines of five `if`s that a new mode had to be threaded into.
class GameStaffView extends ConsumerWidget {
  const GameStaffView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(
      gameControllerProvider.select(
        (game) => (
          score: game.staff,
          cursor: game.cursor,
          gradedColumn: game.gradedColumn,
          played: game.played,
          correct: game.correct,
          scored: game.scored,
        ),
      ),
    );

    return StaffView(
      score: staff.score,
      cursor: staff.cursor,
      played: staff.played,
      correct: staff.correct,
      scored: staff.scored,
      scoredColumn: staff.gradedColumn,
    );
  }
}
