import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../notation/widgets/staff_view.dart';
import '../view_models/game_controller.dart';

/// How large the notation draws, 1.0 being the size it is engraved at.
///
/// The one knob for the staff's size on screen: it shrinks glyphs, staff
/// spacing and margins together, and the view keeps the place and the box it
/// already has. The name rows under it are sized in staff units of their own
/// (`labelSize`), so they do not follow this.
const staffViewScale = 0.9;

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
      scale: staffViewScale,
    );
  }
}
