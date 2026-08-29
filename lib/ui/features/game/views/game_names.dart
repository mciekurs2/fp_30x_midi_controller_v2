import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../notation/widgets/staff_names.dart';
import '../view_models/game_controller.dart';

/// How far the names sit in from the bottom of the screen, mirroring the HUD's
/// inset at the top — they hang off the screen, not off the staff they name.
const nameInset = EdgeInsets.fromLTRB(24, 0, 24, 150);

/// How much higher a round on one stave hangs them.
///
/// The block is one row tall whatever it names, so a grand staff's second row
/// hangs *below* it and a one-hand round leaves that space empty — which reads
/// as the name having drifted away from the staff.
const oneStaveLift = 50.0;

/// The names of what the round is asking for, wired to it — the counterpart to
/// [GameStaffView], which draws the same column on the staff.
class GameNames extends ConsumerWidget {
  const GameNames({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asked = ref.watch(
      gameControllerProvider.select(
        // `hits` counts the asks: the cursor alone stands still in every mode
        // but sheet music, and even there a chord can be asked for twice.
        (game) => (score: game.staff, cursor: game.cursor, turn: game.hits),
      ),
    );
    final lift = asked.score.staves.length > 1 ? 0.0 : oneStaveLift;
    return Padding(
      padding: nameInset.copyWith(bottom: nameInset.bottom + lift),
      child: StaffNames(
        score: asked.score,
        cursor: asked.cursor,
        turn: asked.turn,
      ),
    );
  }
}
