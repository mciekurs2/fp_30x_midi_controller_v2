import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/music_key.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_value.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/pitch.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/glyph.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/score_layout.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/staff_style.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/clef.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/score.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/spelling.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/staff_placement.dart';

/// A phone at its narrowest, which is what the layout has to survive.
const _width = 360.0;
const _height = 800.0;

ScoreLayout _layout(Score score, {double position = 0, double width = _width}) =>
    layoutScore(
      ScoreMeasure(score),
      position: position,
      width: width,
      height: _height,
    );

void main() {
  group('staff placement', () {
    test('the middle line of each clef sits at step zero', () {
      expect(StaffPlacement.inClef(71, Clef.treble).steps, 0); // B4
      expect(StaffPlacement.inClef(50, Clef.bass).steps, 0); // D3
    });

    test('stems hang down on or above the middle line', () {
      expect(StaffPlacement.inClef(71, Clef.treble).stemDown, isTrue);
      expect(StaffPlacement.inClef(60, Clef.treble).stemDown, isFalse);
    });

    test('middle C takes one ledger line in either clef', () {
      expect(StaffPlacement.inClef(60, Clef.treble).ledgerSteps, [-6]);
      expect(StaffPlacement.inClef(60, Clef.bass).ledgerSteps, [6]);
    });

    test('a key excuses its own notes from an accidental', () {
      const dMajor = Spelling.forKey(MusicKey(fifths: 2, tonality: .major));
      // F#4 is diatonic to D major, so the signature has already said it.
      expect(StaffPlacement.inClef(66, Clef.treble, dMajor).accidental, isNull);
      // F natural is not, so it draws one.
      expect(
        StaffPlacement.inClef(65, Clef.treble, dMajor).accidental,
        Accidental.natural,
      );
    });

    test('a respelling key does not move the middle line', () {
      // B→C♭ in G♭ major must not shift the physical line B4 sits on.
      const gFlat = Spelling.forKey(MusicKey(fifths: -6, tonality: .major));
      expect(StaffPlacement.inClef(71, Clef.treble, gFlat).steps, 1);
      expect(StaffPlacement.inClef(71, Clef.treble).steps, 0);
    });

    test('a spelled note keeps the letter it was written with', () {
      // Db4 and C#4 sound the same but sit a staff step apart.
      final dFlat = StaffPlacement.spelled(1, 4, Accidental.flat, Clef.treble);
      final cSharp = StaffPlacement.spelled(0, 4, Accidental.sharp, Clef.treble);
      expect(dFlat.steps - cSharp.steps, 1);
    });

    test('a signature writes F C G D A E B, and drops two in the bass', () {
      const aMajor = MusicKey(fifths: 3, tonality: .major);
      expect(signatureSteps(aMajor, Clef.treble), [4, 1, 5]);
      expect(signatureSteps(aMajor, Clef.bass), [2, -1, 3]);
      expect(signatureSteps(MusicKey.cMajor, Clef.treble), isEmpty);
    });
  });

  group('accidental columns', () {
    List<StaffPlacement> placements(List<int> notes) => [
      for (final note in notes)
        StaffPlacement.inClef(note, Clef.treble, Spelling.flats),
    ];

    test('accidentals a third apart share one column', () {
      // Eb4 and Ab4 are four steps apart, inside the stacking threshold.
      final slots = accidentalSlots(
        placements([63, 68]),
        NoteValue.crotchet,
      );
      expect(slots, hasLength(2));
      expect(slots.first.right, isNot(slots.last.right));
    });

    test('accidentals far apart reuse the innermost column', () {
      // Eb3 and Eb5 are 14 steps apart, so neither crowds the other.
      final slots = accidentalSlots(
        placements([51, 75]),
        NoteValue.crotchet,
      );
      expect(slots.first.right, slots.last.right);
    });

    test('accidentals hang to the left of the notehead', () {
      final slots = accidentalSlots(placements([63]), NoteValue.crotchet);
      expect(slots.single.right, lessThan(0));
    });

    test('an overlay fits around a target already laid out', () {
      final columns = AccidentalColumns();
      final target = accidentalSlots(
        placements([63]),
        NoteValue.crotchet,
        columns: columns,
      );
      // The same step comes back to the same column, landing on the very
      // accidental it is answering.
      final overlay = accidentalSlots(
        placements([63]),
        NoteValue.crotchet,
        columns: columns,
      );
      expect(overlay.single.right, target.single.right);
    });
  });

  group('centred layout', () {
    test('a lone note sits in the middle of the width', () {
      final layout = _layout(Score.chord([60]));
      expect(layout.alignment, ScoreAlignment.centered);
      expect(layout.columnX(0), _width / 2);
      expect(layout.fadeStart, StaffMetrics.fadeStart);
    });

    test('a wide signature steps the note right and pushes the fade out', () {
      // G♭ major carries six flats — the widest signature there is.
      const gFlat = MusicKey(fifths: -6, tonality: .major);
      final layout = _layout(
        Score.chord(
          [66, 70, 73],
          spelling: const Spelling.forKey(gFlat),
          signatureKey: gFlat,
        ),
      );
      expect(layout.columnX(0), greaterThan(_width / 2));
      expect(layout.columnX(0), greaterThan(signatureRight(gFlat, Clef.treble)));
      expect(layout.fadeStart, greaterThan(StaffMetrics.fadeStart));
      expect(layout.fadeStart, lessThanOrEqualTo(0.95));
    });

    test('a key with no accidentals draws no signature', () {
      final score = Score.chord([60], signatureKey: MusicKey.cMajor);
      expect(score.drawnSignature, isNull);
      expect(_layout(score).columnX(0), _width / 2);
    });

    test('an empty score lays out without a column', () {
      final layout = _layout(Score.empty());
      expect(layout.isEmpty, isTrue);
      expect(layout.staves, hasLength(1));
    });
  });

  group('flowing layout', () {
    Score run(int columns) => Score(
      staves: const [Stave(Clef.treble)],
      columns: [
        for (var i = 0; i < columns; i++)
          ScoreColumn(
            voices: [
              ScoreVoice(notes: [ScoreNote(60 + i)]),
            ],
          ),
      ],
    );

    test('the cursor column is anchored at the lead', () {
      final score = run(8);
      for (final cursor in [0, 1, 5]) {
        final layout = _layout(score, position: cursor.toDouble());
        expect(
          layout.columnX(cursor),
          closeTo(layout.lead + layout.extents[cursor]!.left * staffSpace, 1e-9),
          reason: 'column $cursor should sit at the lead',
        );
      }
    });

    test('a fractional position slides the run between two anchors', () {
      final score = run(8);
      final at2 = _layout(score, position: 2).columnX(3);
      final at3 = _layout(score, position: 3).columnX(3);
      final half = _layout(score, position: 2.5).columnX(3);
      expect(half, lessThan(at2));
      expect(half, greaterThan(at3));
    });

    test('the window keeps one column behind and one past the lookahead', () {
      final layout = _layout(run(20), position: 5);
      expect(layout.first, 4);
      expect(layout.last, 5 + scoreWindow);
    });

    test('the window is clamped to the ends of the score', () {
      expect(_layout(run(20), position: 0).first, 0);
      expect(_layout(run(3), position: 2).last, 2);
    });

    test('columns fade back with distance and out behind the cursor', () {
      final layout = _layout(run(20), position: 5);
      expect(layout.alphaAt(5), 1.0);
      expect(layout.alphaAt(6), lessThan(1.0));
      expect(layout.alphaAt(7), lessThan(layout.alphaAt(6)));
      expect(layout.alphaAt(4), 0.0);
    });

    test('a crowded score squeezes the gap rather than running off', () {
      final wide = Score(
        staves: const [Stave(Clef.treble)],
        columns: [
          for (var i = 0; i < 8; i++)
            ScoreColumn(
              voices: [
                ScoreVoice(
                  notes: [
                    // A dense flat chord: three noteheads, three accidentals.
                    ScoreNote(61), ScoreNote(63), ScoreNote(66),
                  ],
                  value: NoteValue.semibreve,
                ),
              ],
            ),
        ],
        spelling: Spelling.flats,
      );
      final measure = ScoreMeasure(wide);
      final lead = leadFor(wide, Clef.treble);
      expect(measure.gapFor(_width, lead), lessThan(columnGap));
      expect(measure.gapFor(_width, lead), greaterThanOrEqualTo(minColumnGap));
    });

    test('the gap is a property of the score, not of the frame', () {
      final measure = ScoreMeasure(run(8));
      final lead = leadFor(run(8), Clef.treble);
      expect(measure.gapFor(_width, lead), measure.gapFor(_width, lead));
    });
  });

  group('staves', () {
    test('two staves straddle the middle, one sits on it', () {
      final grand = Score(
        staves: const [Stave(Clef.treble), Stave(Clef.bass)],
        columns: [
          const ScoreColumn(voices: [null, null]),
        ],
      );
      final layout = _layout(grand);
      expect(layout.topStaveY, lessThan(_height / 2));
      expect(layout.bottomStaveY, greaterThan(_height / 2));
      expect(
        _height / 2 - layout.topStaveY,
        closeTo(layout.bottomStaveY - _height / 2, 1e-9),
      );
      expect(_layout(Score.chord([60])).topStaveY, _height / 2);
    });

    test('held keys split at middle C on a grand staff', () {
      final grand = Score(
        staves: const [Stave(Clef.treble), Stave(Clef.bass)],
        columns: [
          const ScoreColumn(voices: [null, null]),
        ],
      );
      final layout = _layout(grand);
      expect(staveForNote(layout, 60).index, 0);
      expect(staveForNote(layout, 59).index, 1);
      // With one stave everything lands on it.
      expect(staveForNote(_layout(Score.chord([60])), 30).index, 0);
    });
  });

  group('held keys', () {
    test('a key the column asks for takes that note\'s own spelling', () {
      final column = ScoreColumn(
        voices: [
          ScoreVoice(
            notes: [
              // Written Db4 — a C# would sit a staff step away.
              const ScoreNote.spelled(61, letter: 1, octave: 4, drawn: .flat),
            ],
          ),
        ],
      );
      final asked = placeHeldNote(
        61,
        Clef.treble,
        column,
        0,
        Spelling.conventional,
      );
      final unasked = placeHeldNote(
        61,
        Clef.treble,
        const ScoreColumn(voices: [null]),
        0,
        Spelling.conventional,
      );
      expect(asked.steps, unasked.steps + 1);
    });

    test('a key that scored keeps its accidental column', () {
      const value = NoteValue.crotchet;
      List<StaffPlacement> flats(List<int> notes) => [
        for (final note in notes)
          StaffPlacement.inClef(note, Clef.treble, Spelling.flats),
      ];
      final db = flats([61]);

      // Db4 alone, under the target it answered.
      final alone = overlayColumns(scored: db, target: const [], value: value);
      // Still held, with an Ebm triad now on the staff — three flats of its
      // own, all within stacking distance of the Db's.
      final crowded = overlayColumns(
        scored: db,
        target: flats([63, 66, 70]),
        value: value,
      );

      expect(
        crowded.rightFor(db.single.steps, value),
        alone.rightFor(db.single.steps, value),
        reason: 'the new target pushed the scored flat out of its column',
      );
    });

    test('a target with nothing pinned is columned as it was', () {
      const value = NoteValue.crotchet;
      final target = [
        for (final note in [63, 66, 70])
          StaffPlacement.inClef(note, Clef.treble, Spelling.flats),
      ];
      final withPin = overlayColumns(
        scored: const [],
        target: target,
        value: value,
      );
      final bare = AccidentalColumns();
      accidentalSlots(target, value, columns: bare);

      for (final placement in target) {
        expect(
          withPin.rightFor(placement.steps, value),
          bare.rightFor(placement.steps, value),
          reason: 'nothing pinned must leave the target exactly where it was',
        );
      }
    });

    test('a held key takes the value of the note it answers', () {
      final column = ScoreColumn(
        voices: [
          ScoreVoice(notes: [ScoreNote(60)], value: NoteValue.semibreve),
        ],
      );
      expect(heldNoteValue(column, 0), NoteValue.semibreve);
    });

    test('a resting stave borrows the other hand\'s value', () {
      final column = ScoreColumn(
        voices: [
          const ScoreVoice(notes: [], value: NoteValue.crotchet),
          ScoreVoice(notes: [ScoreNote(48)], value: NoteValue.minim),
        ],
      );
      expect(heldNoteValue(column, 0), NoteValue.minim);
    });
  });
}
