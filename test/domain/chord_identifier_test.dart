import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/chord_identifier.dart';

const c4 = 60;

/// Root-position voicing from semitones above middle C.
List<int> on(int root, List<int> intervals) => [
  for (final i in intervals) c4 + root + i,
];

void main() {
  group('every quality, rooted on C', () {
    const cases = {
      'C': [0, 4, 7],
      'Cm': [0, 3, 7],
      'C7': [0, 4, 7, 10],
      'Cmaj7': [0, 4, 7, 11],
      'Cm7': [0, 3, 7, 10],
      'Cdim': [0, 3, 6],
      'Cm7b5': [0, 3, 6, 10],
      'Cdim7': [0, 3, 6, 9],
      'Caug': [0, 4, 8],
      'Csus4': [0, 5, 7],
      'Csus2': [0, 2, 7],
      'C7sus4': [0, 5, 7, 10],
      'C6': [0, 4, 7, 9],
      'Cm6': [0, 3, 7, 9],
      'CmMaj7': [0, 3, 7, 11],
    };
    cases.forEach((name, intervals) {
      test(name, () => expect(playedName(on(0, intervals)), name));
    });
  });

  group('inversions take a slash name', () {
    test('first inversion', () => expect(playedName([64, 67, 72]), 'C/E'));
    test('second inversion', () => expect(playedName([67, 72, 76]), 'C/G'));
    test(
      'seventh in the bass',
      () => expect(playedName([70, 72, 76, 79]), 'C7/Bb'),
    );
    test('root position is bare', () => expect(playedName([60, 64, 67]), 'C'));
  });

  group('voicing does not change the name', () {
    test(
      'doubled root, wide spread',
      () => expect(playedName([48, 64, 67, 72]), 'C'),
    );
    test(
      'order of arrival is irrelevant',
      () => expect(playedName([67, 60, 64]), 'C'),
    );
  });

  group('spelling never mixes signs', () {
    test('Gb, not F#', () => expect(playedName(on(6, [0, 4, 7])), 'Gb'));
    test('C#m, not Dbm', () => expect(playedName(on(1, [0, 3, 7])), 'C#m'));
    test(
      'flat chord takes a flat bass',
      () => expect(playedName([61, 65, 70]), 'Bbm/Db'),
    );
    test(
      'sharp chord takes a sharp bass',
      () => expect(playedName([63, 66, 71]), 'B/D#'),
    );
    test(
      'an unsigned chord takes the conventional bass',
      () => expect(playedName([70, 72, 76, 79]), 'C7/Bb'),
    );
  });

  group('ambiguous sets resolve from the bass', () {
    test('sus2 from its root', () => expect(playedName([60, 62, 67]), 'Csus2'));
    test('sus4 from its root', () => expect(playedName([67, 72, 74]), 'Gsus4'));
    test('m7 from its root', () => expect(playedName([60, 63, 67, 70]), 'Cm7'));
    test(
      'the same notes as a 6th',
      () => expect(playedName([63, 67, 70, 72]), 'Eb6'),
    );
    test(
      'dim7 names from the bass',
      () => expect(playedName([59, 62, 65, 68]), 'Bdim7'),
    );
    test(
      'the same dim7 rolled up',
      () => expect(playedName([62, 65, 68, 71]), 'Ddim7'),
    );
  });

  group('falls back rather than guessing', () {
    test('nothing held', () => expect(playedName([]), isNull));
    test('one key keeps its octave', () => expect(playedName([63]), 'Eb4'));
    test('octaves of one pitch', () => expect(playedName([60, 72]), 'C4'));
    test('two keys are listed', () => expect(playedName([60, 67]), 'C4 G4'));
    test(
      'add9 is outside the catalogue',
      () => expect(playedName([60, 62, 64, 67]), 'C4 D4 E4 G4'),
    );
  });

  group('identifyChord exposes the parts', () {
    test('root and bass', () {
      final chord = identifyChord([64, 67, 72])!;
      expect(chord.root, 0);
      expect(chord.bass, 4);
      expect(chord.inverted, isTrue);
    });
    test(
      'null below three pitches',
      () => expect(identifyChord([60, 64]), isNull),
    );
  });
}
