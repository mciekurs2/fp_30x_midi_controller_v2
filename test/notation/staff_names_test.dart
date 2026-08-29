import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/data/parsing/song_parser.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/song.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/score.dart';
import 'package:fp_30x_midi_controller_v2/notation/widgets/staff_names.dart';

/// The narrowest phone the app targets.
const _phone = Size(360, 800);

void main() {
  final song = parseSong('''
title: Test
key: D major
time: 4/4

RH: | F4 F4 G4 A4 | A4 G4 F4 E4 |
LH: | [D3 A3]w | [A2 E3]w |
''');

  Widget app(Widget child) => MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(width: _phone.width, child: child),
      ),
    ),
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(child));
    await tester.pumpAndSettle();
  }

  testWidgets('the name hands over as the cursor moves', (tester) async {
    final score = Score.song(song, PlayHands.both);
    await pump(tester, StaffNames(score: score, cursor: 1));
    expect(find.text('F#4'), findsOneWidget);

    await tester.pumpWidget(app(StaffNames(score: score, cursor: 2)));
    // One frame in: the next name is already on its way. The rows read the
    // cursor straight, so nothing holds them back to the staff's scroll.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('G4'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('G4'), findsOneWidget);
    expect(find.text('F#4'), findsNothing);
  });

  testWidgets('the same name asked again still hands over', (tester) async {
    // Mid-slide both names are on screen; a name that never left is one.
    final score = Score.chord([60], label: 'C4');
    await pump(tester, StaffNames(score: score));
    expect(find.text('C4'), findsOneWidget);

    // A rebuild that asks for nothing new: the name stays put.
    await tester.pumpWidget(app(StaffNames(score: score)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('C4'), findsOneWidget);

    // The next ask is the same note. It still slides in over the last one.
    await tester.pumpWidget(app(StaffNames(score: score, turn: 1)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('C4'), findsNWidgets(2));
  });

  testWidgets('one row per stave, and none for an empty score', (tester) async {
    await pump(tester, StaffNames(score: Score.song(song, PlayHands.both)));
    expect(find.text('F#4'), findsOneWidget);
    expect(find.text('[D3 A3]'), findsOneWidget);

    await pump(tester, StaffNames(score: Score.song(song, PlayHands.right)));
    expect(find.text('[D3 A3]'), findsNothing);

    await pump(tester, StaffNames(score: Score.empty()));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the block is one row tall however many staves it names', (
    tester,
  ) async {
    // It hangs off the bottom of the screen, so a block sized to its rows grew
    // upward — a grand staff's names ended up over the staff naming them.
    await pump(tester, StaffNames(score: Score.song(song, PlayHands.right)));
    final oneRow = tester.getSize(find.byType(StaffNames)).height;

    await pump(tester, StaffNames(score: Score.song(song, PlayHands.both)));
    final size = tester.getSize(find.byType(StaffNames));
    expect(size.height, oneRow);
    // Full width, or the rows positioned to its edges wrap a character a line.
    expect(size.width, _phone.width);
    // The second row hangs below the first rather than above it.
    expect(
      tester.getTopLeft(find.text('[D3 A3]')).dy,
      greaterThan(tester.getTopLeft(find.text('F#4')).dy),
    );
  });

  testWidgets('a captioned chord is named beside the keys, not under', (
    tester,
  ) async {
    await pump(
      tester,
      StaffNames(
        score: Score.chord([60, 64, 67], label: '[C4 E4 G4]', caption: 'C'),
      ),
    );
    // One line, and the chord bracketed the way the keys are.
    expect(find.text('[C4 E4 G4]  [C]'), findsOneWidget);
  });

  testWidgets('a name too wide for its row shrinks rather than wrapping', (
    tester,
  ) async {
    await pump(
      tester,
      StaffNames(score: Score.chord([60], label: 'C4', caption: 'C')),
    );
    final oneName = tester.getSize(find.byType(StaffNames)).height;

    // A name and its chord on one line run wide on a 360 dp phone. Wrapped,
    // the second line would spill out of the row's reserved height.
    await pump(
      tester,
      StaffNames(
        score: Score.chord([60, 64, 67], label: '[C4 E4 G4]', caption: 'C'),
      ),
    );
    expect(tester.getSize(find.byType(StaffNames)).height, oneName);
    // The name is laid out wider than the row and painted scaled into it.
    final shown = find
        .ancestor(
          of: find.text('[C4 E4 G4]  [C]'),
          matching: find.byType(FittedBox),
        )
        .first;
    expect(tester.getSize(shown).width, lessThanOrEqualTo(_phone.width));
  });

  testWidgets('a stave with nothing to name still holds its row', (
    tester,
  ) async {
    final both = Score.song(song, PlayHands.both);
    await pump(tester, StaffNames(score: both));
    final bassY = tester.getTopLeft(find.text('[D3 A3]')).dy;

    // The same two staves with the treble silent: the row it would have filled
    // has to stay, or the name under it rides up into it.
    final silent = Score(
      staves: both.staves,
      columns: [
        ScoreColumn(voices: [null, both.columns.first.voices.last]),
      ],
      signatureKey: both.signatureKey,
      spelling: both.spelling,
    );
    await pump(tester, StaffNames(score: silent));
    expect(tester.getTopLeft(find.text('[D3 A3]')).dy, bassY);
  });
}
