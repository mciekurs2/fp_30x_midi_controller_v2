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
import 'package:fp_30x_midi_controller_v2/ui/features/game/views/played_readout.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../support/fakes.dart';

/// The narrowest phone the app targets, at the shortest height a round runs at.
const _phone = Size(360, 640);

/// The one overflow the app currently ships with.
///
/// The HUD deliberately keeps v1's layout — a `Spacer` between the two readings
/// rather than a flexible column each — and at the app's 1.5x text scale that
/// runs 25 px past a 360 dp phone. Pinned to its exact size, so any *other*
/// overflow on this page, or a change in this one, still fails the test.
const _acceptedOverflow = 'A RenderFlex overflowed by 25 pixels on the right.';

/// Fails on anything the page threw that is not [_acceptedOverflow], and clears
/// it either way — an exception left pending fails the test at its next pump.
void expectNothingUnexpected(WidgetTester tester, {String? reason}) {
  final error = tester.takeException();
  if (error == null || error.toString() == _acceptedOverflow) return;
  fail([?reason, '$error'].join(': '));
}

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
    expectNothingUnexpected(tester);
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

  /// Taps a control and drains what the page threw drawing the result.
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
    expectNothingUnexpected(tester);
  }

  testWidgets('every mode plays a round on a 360dp phone', (tester) async {
    await pump(tester);

    for (final mode in GameMode.values) {
      container.read(gameSettingsControllerProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();

      await tap(tester, find.text('Play'));

      // Two answered targets: enough to exercise dealing, grading, the score
      // roll, the verdict mark and — in song mode — the scroll.
      await answer(tester);
      await answer(tester);

      expectNothingUnexpected(
        tester,
        reason: '${mode.title} threw while being played',
      );
      expect(
        container.read(gameControllerProvider).score,
        greaterThan(0),
        reason: '${mode.title} scored nothing',
      );

      if (find.text('Stop').evaluate().isNotEmpty) {
        await tap(tester, find.text('Stop'));
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
    expectNothingUnexpected(tester);
  });

  /// The colour the readout is naming the hand in, or `null` when it names
  /// nothing. Mid-transition the switcher holds two, and the incoming one is
  /// last.
  Color? readoutColor(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(PlayedReadout),
          matching: find.byType(Text),
        ),
      )
      .lastOrNull
      ?.style
      ?.color;

  /// A key the round is not asking for and has not already scored.
  int wrongNote(Set<int> correct) => Iterable.generate(
    88,
    (i) => 21 + i,
  ).firstWhere((note) => !correct.contains(note));

  testWidgets('the readout marks a right hand in every mode', (tester) async {
    await pump(tester);
    final notes = container.read(noteSourceProvider.notifier);

    for (final mode in GameMode.values) {
      container.read(gameSettingsControllerProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Play'));

      final targets = container
          .read(gameControllerProvider.notifier)
          .currentTargets();
      for (final note in targets) {
        notes.play(NotePressed(note, 80));
      }
      await tester.pumpAndSettle();
      expect(
        readoutColor(tester),
        successColor,
        reason: '${mode.title}: a hand the round counts as right',
      );
      for (final note in targets) {
        notes.play(NoteReleased(note));
      }
      await tester.pumpAndSettle();

      final wrong = wrongNote(container.read(gameControllerProvider).correct);
      notes.play(NotePressed(wrong, 80));
      await tester.pumpAndSettle();
      expect(
        readoutColor(tester),
        accentColor,
        reason: '${mode.title}: a key the round is not asking for',
      );
      notes.play(NoteReleased(wrong));
      await tester.pumpAndSettle();

      expectNothingUnexpected(tester, reason: '${mode.title} threw');
      if (find.text('Stop').evaluate().isNotEmpty) {
        await tap(tester, find.text('Stop'));
      }
    }
  });

  testWidgets('the readout stays the accent with no round to grade it', (
    tester,
  ) async {
    await pump(tester);
    final notes = container.read(noteSourceProvider.notifier);
    for (final note in [60, 64, 67]) {
      notes.play(NotePressed(note, 80));
    }
    await tester.pumpAndSettle();
    expect(readoutColor(tester), accentColor);
    expectNothingUnexpected(tester);
  });

  testWidgets('the controls lock while a round runs', (tester) async {
    await pump(tester);
    final picker = find.byIcon(Icons.sports_esports);
    expect(tester.widget<FilledButton>(
      find.ancestor(of: picker, matching: find.byType(FilledButton)),
    ).onPressed, isNotNull);

    await tap(tester, find.text('Play'));
    expect(tester.widget<FilledButton>(
      find.ancestor(of: picker, matching: find.byType(FilledButton)),
    ).onPressed, isNull);
  });
}
