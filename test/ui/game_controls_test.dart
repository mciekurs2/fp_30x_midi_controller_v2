import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/core/providers.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/game_mode.dart';
import 'package:fp_30x_midi_controller_v2/ui/core/theme/app_theme.dart';
import 'package:fp_30x_midi_controller_v2/ui/features/game/views/game_controls.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../support/fakes.dart';

/// A short phone: the least room a sheet ever has to fit into.
const _shortPhone = Size(360, 640);

/// Whether the chip labelled [label] is the one in force. The chips carry the
/// choice on their own — a sheet header repeating it would only say it twice.
bool chosenChip(WidgetTester tester, String label) => tester
    .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
    .selected;

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = _shortPhone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(
            FakePreferencesService(),
          ),
          songAssetServiceProvider.overrideWithValue(
            FakeSongAssetService(const {
              'a.song': 'title: A chart\nRH: C4 D4\n',
            }),
          ),
          midiDeviceServiceProvider.overrideWithValue(FakeMidiDeviceService()),
        ],
        child: MaterialApp(
          theme: appTheme(),
          builder: withTextScale,
          home: const Scaffold(
            body: Align(alignment: .bottomLeft, child: GameControls()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the modal barrier above the sheet, which pops it.
  Future<void> dismiss(WidgetTester tester) async {
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();
  }

  Future<void> chooseMode(WidgetTester tester, GameMode mode) async {
    await tester.tap(find.byIcon(Icons.sports_esports));
    await tester.pumpAndSettle();
    // The mode's title is also on the picker button, so take the sheet's row.
    await tester.tap(find.widgetWithText(ListTile, mode.title));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  }

  testWidgets('every mode\'s settings sheet fits a short phone', (
    tester,
  ) async {
    // A RenderFlex overflow surfaces as a thrown exception under test, so this
    // is the guard against a sheet that no longer fits.
    await pump(tester);
    for (final mode in GameMode.values) {
      await chooseMode(tester, mode);
      await openSettings(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: '${mode.title} settings overflowed',
      );
      await dismiss(tester);
    }
  });

  testWidgets('a mode shows exactly the knobs it declares', (tester) async {
    await pump(tester);

    await chooseMode(tester, GameMode.singleNote);
    await openSettings(tester);
    expect(find.text('Time limit'), findsOneWidget);
    expect(find.text('Octaves'), findsOneWidget);
    expect(find.text('Key'), findsNothing);
    expect(find.text('Song'), findsNothing);
    await dismiss(tester);

    await chooseMode(tester, GameMode.keyChords);
    await openSettings(tester);
    expect(find.text('Key'), findsOneWidget);
    expect(find.text('Octaves'), findsOneWidget);
    await dismiss(tester);

    await chooseMode(tester, GameMode.song);
    await openSettings(tester);
    // A piece is self-paced, so the clock and octave knobs do not apply.
    expect(find.text('Song'), findsOneWidget);
    expect(find.text('Hands'), findsOneWidget);
    expect(find.text('Time limit'), findsNothing);
    expect(find.text('Octaves'), findsNothing);
  });

  testWidgets('the hands picker offers every hand', (tester) async {
    await pump(tester);
    await chooseMode(tester, GameMode.song);
    await openSettings(tester);

    expect(find.widgetWithText(ChoiceChip, 'Right'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Left'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Both'), findsOneWidget);

    // The chips carry the choice; nothing else on the sheet repeats it.
    expect(chosenChip(tester, 'Right'), isTrue);
    expect(chosenChip(tester, 'Left'), isFalse);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Left'));
    await tester.pumpAndSettle();
    expect(chosenChip(tester, 'Left'), isTrue);
    expect(chosenChip(tester, 'Right'), isFalse);
  });

  testWidgets('the key picker re-spells itself with the tonality', (
    tester,
  ) async {
    await pump(tester);
    await chooseMode(tester, GameMode.keyChords);
    await openSettings(tester);

    expect(chosenChip(tester, 'C'), isTrue);
    expect(chosenChip(tester, 'Major'), isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, 'G'));
    await tester.pumpAndSettle();
    expect(chosenChip(tester, 'G'), isTrue);
    expect(chosenChip(tester, 'C'), isFalse);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Minor'));
    await tester.pumpAndSettle();
    expect(chosenChip(tester, 'G'), isTrue);
    expect(chosenChip(tester, 'Minor'), isTrue);
    // Pitch class 6 reads Gb as a major and F# as a minor.
    expect(find.widgetWithText(ChoiceChip, 'Gb'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'F#'), findsOneWidget);
  });

  testWidgets('the song picker lists the library', (tester) async {
    await pump(tester);
    await chooseMode(tester, GameMode.song);
    await openSettings(tester);
    expect(find.text('A chart'), findsOneWidget);
  });
}
