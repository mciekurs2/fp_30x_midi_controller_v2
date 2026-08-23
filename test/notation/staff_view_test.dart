import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/data/parsing/song_parser.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/music_key.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_value.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/song.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/score.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/spelling.dart';
import 'package:fp_30x_midi_controller_v2/notation/widgets/staff_view.dart';

/// The narrowest phone the app targets — where a six-accidental signature is
/// snug and a two-stave system with name rows has the least room.
const _phone = Size(360, 800);

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Center(child: SizedBox.fromSize(
          size: _phone,
          child: child,
        ))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a signature in all 24 keys renders without overflowing', (
    tester,
  ) async {
    for (var pitchClass = 0; pitchClass < 12; pitchClass++) {
      for (final key in [
        MusicKey.major(pitchClass),
        MusicKey.minor(pitchClass),
      ]) {
        // The tonic triad, drawn bare under its own signature.
        final root = 60 + key.tonicPitchClass;
        await pump(
          tester,
          StaffView(
            score: Score.chord(
              [root, root + 4, root + 7],
              value: NoteValue.semibreve,
              spelling: Spelling.forKey(key),
              signatureKey: key,
              label: key.tonicName,
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'staff overflowed in ${key.name}',
        );
      }
    }
  });

  testWidgets('an unsigned staff and an empty staff both render', (
    tester,
  ) async {
    await pump(tester, StaffView(score: Score.chord([60], label: 'C4')));
    expect(tester.takeException(), isNull);

    await pump(tester, StaffView(score: Score.empty()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('held keys overlay the target without overflowing', (
    tester,
  ) async {
    await pump(
      tester,
      StaffView(
        score: Score.chord([60, 64, 67], label: 'C'),
        played: const {60, 61},
        correct: const {60},
        scored: const {64},
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a key held across a target change keeps its writing', (
    tester,
  ) async {
    Widget staffFor(Score score) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            size: _phone,
            child: StaffView(
              score: score,
              // G3 is held throughout: it scored under the bass target and is
              // still down when a treble one is dealt.
              played: const {},
              scored: const {55},
            ),
          ),
        ),
      ),
    );

    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(staffFor(Score.chord([55], label: 'G3')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The next target is in the treble, so the held key brings its own clef.
    await tester.pumpWidget(staffFor(Score.chord([72], label: 'C5')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('sheet music', () {
    final song = parseSong('''
title: Test
key: D major
time: 4/4

RH: | F4 F4 G4 A4 | A4 G4 F4 E4 |
LH: | [D3 A3]w | [A2 E3]w |
''');

    testWidgets('a grand staff renders at every cursor position', (
      tester,
    ) async {
      for (var cursor = 0; cursor < song.columns.length; cursor++) {
        await pump(
          tester,
          StaffView(score: Score.song(song, PlayHands.both), cursor: cursor),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'grand staff overflowed at column $cursor',
        );
      }
    });

    testWidgets('one hand draws one stave, both draw two', (tester) async {
      expect(Score.song(song, PlayHands.right).staves, hasLength(1));
      expect(Score.song(song, PlayHands.left).staves, hasLength(1));
      expect(Score.song(song, PlayHands.both).staves, hasLength(2));

      await pump(
        tester,
        StaffView(score: Score.song(song, PlayHands.right), cursor: 2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the score scrolls as the cursor advances', (tester) async {
      final score = Score.song(song, PlayHands.both);
      await pump(tester, StaffView(score: score));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: _phone,
                child: StaffView(score: score, cursor: 1),
              ),
            ),
          ),
        ),
      );
      // Mid-tween, then settled: neither frame may throw.
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
