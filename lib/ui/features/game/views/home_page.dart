import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../connection/views/connection_badge.dart';
import '../../debug/views/test_controls.dart';
import '../view_models/game_controller.dart';
import 'game_controls.dart';
import 'game_hud.dart';
import 'game_staff_view.dart';
import 'play_button.dart';

/// The only screen: the HUD pinned top, the staff centred, and the controls
/// along the bottom — play and settings on the left, the piano's connection
/// (and, in debug builds, the keyboard stand-in) on the right.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A round that could not start says so, rather than looking like a dead
    // Play button — a chart that will not parse is the realistic case.
    ref.listen(gameControllerProvider.select((game) => game.error), (
      _,
      error,
    ) {
      if (error == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    });

    return const Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: .fromLTRB(24, 8, 24, 0),
              child: GameHud(),
            ),
            Center(child: GameStaffView()),
            Align(
              alignment: .bottomCenter,
              child: Padding(
                padding: .fromLTRB(12, 0, 12, 12),
                // Both sides are flexible rather than one pushing the other
                // out: at the app's 1.5x text scale the two do not both fit at
                // their natural width on a 360 dp phone.
                child: Row(
                  crossAxisAlignment: .end,
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .start,
                        children: [
                          PlayButton(),
                          SizedBox(height: 8),
                          GameControls(),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .end,
                        children: [
                          if (kDebugMode) ...[
                            TestControls(),
                            SizedBox(height: 8),
                          ],
                          ConnectionBadge(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
