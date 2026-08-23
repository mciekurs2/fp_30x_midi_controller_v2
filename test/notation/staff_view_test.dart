import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/data/parsing/song_parser.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/music_key.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_value.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/song.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/clef.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/score.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/staff_placement.dart';
import 'package:fp_30x_midi_controller_v2/notation/painting/score_painter.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/spelling.dart';
import 'package:fp_30x_midi_controller_v2/notation/widgets/staff_view.dart';

/// The narrowest phone the app targets — where a six-accidental signature is
/// snug and a two-stave system with name rows has the least room.
const _phone = Size(360, 800);

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Center(child: SizedBox.fromSize(size: _phone, child: child)),
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

  /// How many of the staff's layers are on screen. A layer that is animating in
  /// has two — the outgoing copy and the incoming one — so a count of one is
  /// proof the entry animation did not replay.
  int layers<T>(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .where((paint) => paint.painter is T)
      .length;

  testWidgets('a wrong press does not re-animate the target', (tester) async {
    final target = Score.chord([60, 64, 67], label: 'C');
    await pump(tester, StaffView(score: target));
    expect(layers<ColumnsPainter>(tester), 1);
    expect(layers<ClefPainter>(tester), 1);

    // A wrong key. The staff rebuilds, but nothing written has changed.
    await tester.pumpWidget(app(StaffView(score: target, played: const {62})));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      layers<ColumnsPainter>(tester),
      1,
      reason: 'the notes dropped in again on a wrong press',
    );
    expect(
      layers<ClefPainter>(tester),
      1,
      reason: 'the clef faded in again on a wrong press',
    );

    // A fresh Score holding the same notes is still the same thing to read.
    await tester.pumpWidget(
      app(StaffView(score: Score.chord([60, 64, 67], label: 'C'))),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      layers<ColumnsPainter>(tester),
      1,
      reason: 'an unchanged target re-animated when its Score was rebuilt',
    );
  });

  testWidgets('a new target animates in', (tester) async {
    await pump(tester, StaffView(score: Score.chord([60, 64, 67])));

    // Same clef, different notes: the notes swap, the clef stays put.
    await tester.pumpWidget(app(StaffView(score: Score.chord([65, 69, 72]))));
    await tester.pump(const Duration(milliseconds: 16));
    expect(layers<ColumnsPainter>(tester), 2);
    expect(layers<ClefPainter>(tester), 1);

    await tester.pumpAndSettle();
    expect(layers<ColumnsPainter>(tester), 1);

    // Down into the bass: the clef changes too.
    await tester.pumpWidget(app(StaffView(score: Score.chord([41, 45, 48]))));
    await tester.pump(const Duration(milliseconds: 16));
    expect(layers<ClefPainter>(tester), 2);
  });

  /// Where the held-key overlay is drawing.
  double overlayX(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<OverlayPainter>()
      .where((painter) => painter.notes.isNotEmpty)
      .single
      .x;

  testWidgets('held keys animate in and out', (tester) async {
    final target = Score.chord([60, 64, 67], label: 'C');
    await pump(tester, StaffView(score: target));
    expect(tester.hasRunningAnimations, isFalse);

    // A wrong key goes down: it drops in rather than appearing.
    await tester.pumpWidget(app(StaffView(score: target, played: const {62})));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'a pressed key appeared with no entry animation',
    );
    await tester.pumpAndSettle();

    // Wrong turns right. Same key, new colour — a repaint, not a re-entry.
    await tester.pumpWidget(
      app(StaffView(score: target, played: const {62}, correct: const {62})),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'the key re-animated when it only changed colour',
    );

    // And it drops back out on release.
    await tester.pumpWidget(app(StaffView(score: target)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'a released key vanished with no exit animation',
    );
  });

  testWidgets('the clef a held key brings with it animates', (tester) async {
    // Struck under a bass target, so it is written in bass...
    await pump(
      tester,
      StaffView(score: Score.chord([48]), played: const {41}),
    );
    expect(layers<ClefPainter>(tester), 1);

    // ...and still down when the next target is up in the treble. It keeps its
    // bass writing, so the bass clef comes along to read it against.
    await tester.pumpWidget(
      app(StaffView(score: Score.chord([72]), played: const {41})),
    );
    await tester.pumpAndSettle();
    expect(
      layers<ClefPainter>(tester),
      2,
      reason: 'no bass clef was brought along',
    );

    await tester.pumpWidget(app(StaffView(score: Score.chord([72]))));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'the extra clef vanished with no exit animation',
    );
  });

  testWidgets('a scored key holds the target column', (tester) async {
    // A centred score draws its column at the middle of the staff. A key that
    // scored and is still down belongs on that column, not shifted onto the
    // left-anchored position a flowing score would pin it to.
    await pump(
      tester,
      StaffView(score: Score.chord([60]), played: const {60}, correct: const {60}),
    );
    final live = overlayX(tester);

    await tester.pumpWidget(
      app(StaffView(
        score: Score.chord([60]),
        scored: const {60},
        correct: const {60},
      )),
    );
    await tester.pumpAndSettle();
    expect(overlayX(tester), live);
  });

  /// The held keys the overlay is drawing, and how each is written.
  List<HeldNote> heldNotes(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<OverlayPainter>()
      .expand((painter) => painter.notes)
      .toList();

  group('a key that scored', () {
    // The real sequence: the press is graded and the next target dealt in one
    // step, so the first frame that key is ever drawn on is already under the
    // target *after* the one it answered.
    Future<void> scoreThenDeal(
      WidgetTester tester, {
      required int answered,
      required int next,
    }) async {
      await pump(tester, StaffView(score: Score.chord([answered])));
      await tester.pumpWidget(
        app(StaffView(
          score: Score.chord([next]),
          scored: {answered},
          correct: {answered},
        )),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the clef of the target it answered', (tester) async {
      // Answered down in the bass, next target up in the treble.
      await scoreThenDeal(tester, answered: 48, next: 84);

      expect(
        heldNotes(tester).single.placement.clef,
        Clef.bass,
        reason: 'the green key was re-written into the new target\'s clef',
      );
      // And the clef it is written in comes along to read it against.
      expect(layers<ClefPainter>(tester), 2);
    });

    testWidgets('keeps the spelling it was played under', (tester) async {
      // Same clef either way, so nothing but the remembered spelling keeps this
      // note off the wrong step: Db and C# are one key but two staff positions,
      // and the chords mode writes each chord all-flats or all-sharps.
      await pump(
        tester,
        StaffView(score: Score.chord([61], spelling: Spelling.flats)),
      );
      await tester.pumpWidget(
        app(StaffView(
          score: Score.chord([66], spelling: Spelling.sharps),
          scored: const {61},
          correct: const {61},
        )),
      );
      await tester.pumpAndSettle();

      expect(
        heldNotes(tester).single.placement.steps,
        StaffPlacement.inClef(61, Clef.treble, Spelling.flats).steps,
        reason: 'the green key was re-spelled by the next chord',
      );
    });

    testWidgets('a key that did not score is written the current way', (
      tester,
    ) async {
      // A wrong key is not answering anything, so it belongs to the target on
      // screen now — v1 drew it that way too.
      await pump(tester, StaffView(score: Score.chord([48])));
      await tester.pumpWidget(
        app(StaffView(score: Score.chord([84]), played: const {83})),
      );
      await tester.pumpAndSettle();

      expect(heldNotes(tester).single.placement.clef, Clef.treble);
    });
  });

  testWidgets('a scored key is handed to the overlay as pinned', (
    tester,
  ) async {
    // Db4 struck under its own target, then held into a flat chord that brings
    // three accidentals of its own. The painter has to know which note already
    // scored, or it columns the new target first and shoves the green flat left.
    await pump(
      tester,
      StaffView(
        score: Score.chord([63, 66, 70], spelling: Spelling.flats, label: 'Ebm'),
        played: const {},
        correct: const {61},
        scored: const {61},
      ),
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<OverlayPainter>()
        .single;
    expect(painter.scored, {61});
  });

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

    testWidgets('the name hands over as the cursor moves, not as it lands', (
      tester,
    ) async {
      final score = Score.song(song, PlayHands.both);
      await pump(tester, StaffView(score: score, cursor: 1));
      expect(find.text('F#4'), findsOneWidget);

      await tester.pumpWidget(app(StaffView(score: score, cursor: 2)));
      // One frame in, with the 340 ms scroll barely started: the next name is
      // already on its way in. Reading the scroll instead of the cursor held it
      // back until the scroll landed.
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('G4'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('G4'), findsOneWidget);
      expect(find.text('F#4'), findsNothing);
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
