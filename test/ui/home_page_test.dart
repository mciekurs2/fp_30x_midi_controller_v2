import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/core/providers.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/game_mode.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_event.dart';
import 'package:fp_30x_midi_controller_v2/ui/core/theme/app_theme.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/game_controller.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/game_settings_controller.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/view_models/note_source.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/views/home_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../support/fakes.dart';

/// The narrowest phone the app targets, at the shortest height a round runs at.
const _phone = Size(360, 640);

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final scope = ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(FakePreferencesService()),
        songAssetServiceProvider.overrideWithValue(
          FakeSongAssetService(const {
            'a.song': 'title: A chart\nkey: D major\n'
                'RH: F4 G4 A4\nLH: [D3 A3]w\n',
          }),
        ),
        midiDeviceServiceProvider.overrideWithValue(FakeMidiDeviceService()),
      ],
      child: MaterialApp(
        theme: appTheme(),
        builder: withTextScale,
        home: const HomePage(),
      ),
    );
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
  }

  /// Plays every note the round is asking for, and lets go again.
  Future<void> answer(WidgetTester tester) async {
    final notes = container.read(noteSourceProvider.notifier);
    final targets = container
        .read(gameControllerProvider.notifier)
        .currentTargets();
    for (final note in targets) {
      notes.play(NotePressed(note, 80));
    }
    await tester.pumpAndSettle();
    for (final note in targets) {
      notes.play(NoteReleased(note));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('every mode plays a round on a 360dp phone', (tester) async {
    await pump(tester);

    for (final mode in GameMode.values) {
      container.read(gameSettingsControllerProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Two answered targets: enough to exercise dealing, grading, the score
      // roll, the verdict mark and — in song mode — the scroll.
      await answer(tester);
      await answer(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: '${mode.title} threw while being played',
      );
      expect(
        container.read(gameControllerProvider).score,
        greaterThan(0),
        reason: '${mode.title} scored nothing',
      );

      if (find.text('Stop').evaluate().isNotEmpty) {
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('the readout names what is under the hands', (tester) async {
    await pump(tester);
    final notes = container.read(noteSourceProvider.notifier);

    for (final note in [60, 64, 67]) {
      notes.play(NotePressed(note, 80));
    }
    await tester.pumpAndSettle();
    expect(find.text('C'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the controls lock while a round runs', (tester) async {
    await pump(tester);
    final picker = find.byIcon(Icons.sports_esports);
    expect(tester.widget<FilledButton>(
      find.ancestor(of: picker, matching: find.byType(FilledButton)),
    ).onPressed, isNotNull);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(
      find.ancestor(of: picker, matching: find.byType(FilledButton)),
    ).onPressed, isNull);
  });
}
