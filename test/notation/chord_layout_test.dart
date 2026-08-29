import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_value.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/chord_layout.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/glyph.dart';
import 'package:fp_30x_midi_controller_v2/notation/layout/score_layout.dart';
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

    test('a triad takes the nominal stem length from its lowest head', () {
      // C4-E4-G4 is narrower than a stem is long, so the tip lands where a
      // lone C4's would: half a space above the middle line.
      final chord = _chord([60, 64, 67]);
      expect(
        chord.stem!.to,
        StaffMetrics.y(chord.steps.first) + StaffMetrics.stemLength,
      );
    });

    test('a chord wider than a stem lengthens it past the far head', () {
      // G2-D3-G3, the left hand of blue.song's intro: an octave, wider than a
      // stem is long. Measured past the top head instead it would reach a
      // whole staff up, through the treble stave of the same system.
      final chord = layoutChord(
        [
          for (final note in [43, 50, 55])
            StaffPlacement.inClef(note, Clef.bass),
        ],
        NoteValue.crotchet,
      );
      expect(chord.stemDown, isFalse);
      final top = StaffMetrics.y(chord.steps.last);
      expect(chord.stem!.to, top + StaffMetrics.stemOverhang);
      expect(chord.stem!.to, lessThan(top + StaffMetrics.stemLength));
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
  });
}
