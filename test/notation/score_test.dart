import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/data/parsing/song_parser.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/song.dart';
import 'package:fp_30x_midi_controller_v2/notation/model/score.dart';

/// The captions of the first column, treble row first.
List<String?> _captions(Score score) => [
  for (final voice in score.columns.first.voices) voice?.caption,
];

void main() {
  group('a hand is captioned by its own notes', () {
    test('a hand that spells no chord is left unnamed', () {
      // The two hands together are a plain D major; neither holds it alone,
      // and naming the pair would caption a chord the reader is not playing.
      final song = parseSong('''
key: D major

RH: F4
LH: [D3 A3]
''');
      expect(_captions(Score.song(song, PlayHands.both)), [isNull, isNull]);
    });

    test('a hand holding a chord is named for it', () {
      final song = parseSong('''
RH: [C4 E4 G4]
LH: [C2 G2 E3]
''');
      expect(_captions(Score.song(song, PlayHands.both)), ['C', 'C']);
      expect(_captions(Score.song(song, PlayHands.right)), ['C']);
    });
  });
}
