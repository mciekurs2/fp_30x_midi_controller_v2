import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_value.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/chord_layout.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/glyph.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/score_layout.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/staff_style.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/clef.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/score.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/spelling.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/staff_placement.dart';

List<StaffPlacement> _treble(List<int> notes) => [
  for (final note in notes) StaffPlacement.inClef(note, Clef.treble),
];

ChordLayout _chord(
  List<int> notes, {
  NoteValue value = NoteValue.crotchet,
  ChordLayout? follow,
}) => layoutChord(_treble(notes), value, follow: follow);

/// The head at [index], as a distance from the main column — 0 on the main
/// side, one notehead either way when it is displaced across the stem.
double _offset(ChordLayout chord, int index) =>
    chord.heads[index] - chord.value.leftEdge;

void main() {
  group('stem direction', () {
    test('a lone note follows the middle line', () {
      // B4 sits on it, C4 well below: the old per-note rule, unchanged.
      expect(_chord([71]).stemDown, isTrue);
      expect(_chord([60]).stemDown, isFalse);
    });

    test('the head furthest from the middle line decides for the chord', () {
      // C4-G4-B4, the chord under bars 9-10 of blue.song. B4 is on the middle
      // line and C4 six steps under it, so the whole chord stems up — drawing
      // each head its own way put two stems up and one down through the same
      // notes.
      final chord = _chord([60, 67, 71]);
      expect(chord.stemDown, isFalse);
      expect(chord.stem, isNotNull);
      // One stem, growing out of the lowest head and reaching past the top.
      expect(chord.stemAnchor, 0);
      expect(chord.stem!.from, StaffMetrics.y(chord.steps.first));
      expect(chord.stem!.to, greaterThan(StaffMetrics.y(chord.steps.last)));
    });

    test('a lone note reaches a stem past itself', () {
      final note = _chord([60]);
      expect(
        note.stem!.to,
        StaffMetrics.y(note.steps.first) + StaffMetrics.stemLength,
      );
    });

    test('a chord clears its top head by the overhang, whatever its span', () {
      // The stem grows with the chord rather than the tip closing on the top
      // head as the chord widens — which is what a nominal length measured
      // from the head it grows *out of* does, and it reads stubby.
      for (final notes in [
        [60, 64, 67],
        [59, 62, 64, 67],
      ]) {
        final chord = _chord(notes);
        expect(chord.stemDown, isFalse);
        expect(
          chord.stem!.to,
          closeTo(
            StaffMetrics.y(chord.steps.last) + StaffMetrics.stemOverhang,
            1e-9,
          ),
          reason: '$notes',
        );
      }
    });

    test('a narrow interval keeps a lone note\'s length', () {
      // C4-E4: a third, close enough that the nominal length still reaches
      // further than clearing the top head would.
      final chord = _chord([60, 64]);
      expect(
        chord.stem!.to,
        StaffMetrics.y(chord.steps.first) + StaffMetrics.stemLength,
      );
    });

    test('a bass octave clears the stave above it', () {
      // G2-D3-G3, the left hand of blue.song's intro. Its stem is the tallest
      // in the chart, and `staffHalfGap` is what keeps the tip clear of a
      // treble note hanging below its own stave — B3, in the same song.
      final chord = layoutChord(
        [
          for (final note in [43, 50, 55])
            StaffPlacement.inClef(note, Clef.bass),
        ],
        NoteValue.crotchet,
      );
      final b3 = StaffMetrics.y(StaffPlacement.inClef(59, Clef.treble).steps);
      expect(chord.stem!.to, lessThan(b3 + 2 * staffHalfGap - 1));
    });

    test('a chord reaching further above the line hangs its stem down', () {
      expect(_chord([71, 76, 79]).stemDown, isTrue);
    });

    test('a semibreve carries no stem', () {
      expect(_chord([60, 64], value: NoteValue.semibreve).stem, isNull);
    });
  });

  group('seconds', () {
    test('a stem-up chord displaces the upper head to the right', () {
      // B3-D4-E4-G4, the G6 the intro of blue.song alternates: D4 and E4 are a
      // second, and drawn on one x they print as a single blot.
      final chord = _chord([59, 62, 64, 67]);
      expect(chord.stemDown, isFalse);
      expect(_offset(chord, 0), 0);
      expect(_offset(chord, 1), 0);
      expect(_offset(chord, 2), greaterThan(0));
      expect(_offset(chord, 3), 0);
      // The pair shares the stem rather than clearing it.
      expect(
        _offset(chord, 2),
        NoteValue.crotchet.headWidth - StaffMetrics.stemWidth,
      );
    });

    test('a stem-down chord displaces the lower head to the left', () {
      // A5-B5, high enough that the stem hangs down.
      final chord = _chord([81, 83]);
      expect(chord.stemDown, isTrue);
      expect(_offset(chord, 0), lessThan(0));
      expect(_offset(chord, 1), 0);
    });

    test('a cluster alternates across the stem', () {
      // C4-D4-E4-F4: every neighbour is a second, so they cannot all fall on
      // one side. Walking up from the stem's foot, every other head crosses.
      final chord = _chord([60, 62, 64, 65]);
      expect(chord.stemDown, isFalse);
      expect(_offset(chord, 0), 0);
      expect(_offset(chord, 1), greaterThan(0));
      expect(_offset(chord, 2), 0);
      expect(_offset(chord, 3), greaterThan(0));
    });

    test('a third is left alone', () {
      final chord = _chord([60, 64, 67]);
      expect([for (var i = 0; i < 3; i++) _offset(chord, i)], [0, 0, 0]);
    });

    test('two heads on one step do not print on top of each other', () {
      // F4 and F#4 spelled sharp share a staff position.
      final chord = layoutChord(
        [
          StaffPlacement.inClef(65, Clef.treble, Spelling.sharps),
          StaffPlacement.inClef(66, Clef.treble, Spelling.sharps),
        ],
        NoteValue.crotchet,
      );
      expect(chord.steps.first, chord.steps.last);
      expect(chord.heads.first, isNot(chord.heads.last));
    });
  });

  group('the overlay follows the target', () {
    test('a held key lands on the head it is answering', () {
      final target = _chord([59, 62, 64, 67]);
      // E4 alone would sit on the main column; under the target it has to take
      // the displaced place, or the green head lands beside the black one.
      final held = _chord([64], follow: target);
      expect(held.heads.single, target.heads[2]);
      expect(held.stemDown, target.stemDown);
    });

    test('a held key lies along the target stem, never past it', () {
      final target = _chord([59, 62, 64, 67]);
      for (final note in [59, 62, 64, 67]) {
        final held = _chord([note], follow: target);
        expect(held.stem!.x, target.stem!.x);
        expect(
          held.stem!.to,
          target.stem!.to,
          reason: 'the overlay shot past the stem it is drawn over',
        );
        // The foot is the key's own head, so only the stem it reaches along is
        // tinted — the top note alone must not colour the whole chord's stem.
        expect(held.stem!.from, StaffMetrics.y(held.steps.single));
      }
      expect(
        _chord([67], follow: target).stem!.from,
        greaterThan(_chord([59], follow: target).stem!.from),
      );
    });

    test('a key the target never asked for stretches the stem to reach it', () {
      final target = _chord([71, 76]);
      expect(target.stemDown, isTrue);
      // C4, far below anything written: the stem has to come down to it.
      final held = _chord([60], follow: target);
      expect(held.stemDown, isTrue);
      expect(held.stem!.to, lessThan(target.stem!.to));
    });
  });

  group('measurement', () {
    Extent extentOf(List<int> notes, {NoteValue value = NoteValue.crotchet}) =>
        voiceExtent(
          ScoreVoice(
            notes: [for (final note in notes) ScoreNote(note)],
            value: value,
          ),
          Clef.treble,
          Spelling.conventional,
        );

    test('a displaced head widens the column on its own side', () {
      final third = extentOf([60, 64]);
      final second = extentOf([60, 62]);
      expect(second.right, greaterThan(third.right));
      expect(second.left, third.left);
    });

    test('a stem-down chord widens to the left instead', () {
      final plain = extentOf([81]);
      final second = extentOf([81, 83]);
      expect(second.left, greaterThan(plain.left));
    });

    test("a quaver's flag is measured, not just its head", () {
      final quaver = extentOf([60], value: NoteValue.quaver);
      final crotchet = extentOf([60]);
      expect(quaver.right, greaterThan(crotchet.right));
    });

    test('a semiquaver takes the double-hooked flag, and is measured by it', () {
      expect(
        NoteValue.semiquaver.flag(stemDown: false),
        MusicSymbol.flag16thUp,
      );
      expect(
        NoteValue.semiquaver.flag(stemDown: true),
        MusicSymbol.flag16thDown,
      );
      expect(
        extentOf([60], value: NoteValue.semiquaver).right,
        greaterThan(extentOf([60]).right),
      );
    });
  });
}
