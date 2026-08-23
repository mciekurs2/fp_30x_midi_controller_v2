import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/data/parsing/song_parser.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/music_key.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_value.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/pitch.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/song.dart';

void main() {
  group('header', () {
    test('reads title, key and time', () {
      final song = parseSong('''
title: Ode to Joy
key: D major
time: 3/4

RH: F4
''');
      expect(song.title, 'Ode to Joy');
      expect(song.key, MusicKey.major(2));
      expect(song.beatsPerBar, 3);
      expect(song.beatUnit, 4);
      expect(song.barlines, isTrue);
    });

    test('reads a minor key', () {
      expect(parseSong('key: B minor\nRH: B3\n').key, MusicKey.minor(11));
    });

    test('barlines can be switched off', () {
      for (final off in ['off', 'no', 'none', 'false']) {
        expect(parseSong('barlines: $off\nRH: C4\n').barlines, isFalse);
      }
      expect(parseSong('barlines: on\nRH: C4\n').barlines, isTrue);
    });

    test('an absent header falls back', () {
      final song = parseSong('RH: C4\n');
      expect(song.title, 'Untitled');
      expect(song.key, isNull);
      expect(song.beatsPerBar, 4);
    });
  });

  group('pitch', () {
    SongNote first(String text) => parseSong(text).rh!.first.notes.first;

    test('middle C is MIDI 60', () {
      expect(first('RH: C4').midi, 60);
    });

    test('accidentals are key-implicit', () {
      // A bare F in D major *is* F#, and draws nothing: the signature said it.
      final implied = first('key: D major\nRH: F4');
      expect(implied.midi, 66);
      expect(implied.drawn, isNull);
      expect(implied.name, 'F#4');
    });

    test('a written accidental departs from the signature and is drawn', () {
      final natural = first('key: D major\nRH: Fn4');
      expect(natural.midi, 65);
      expect(natural.drawn, Accidental.natural);

      final flat = first('RH: Eb3');
      expect(flat.midi, 51);
      expect(flat.drawn, Accidental.flat);
    });

    test('the written letter is kept, not just the pitch', () {
      // Db4 and C#4 sound alike; the file decides which is drawn.
      expect(first('RH: Db4').letter, 1);
      expect(first('RH: C#4').letter, 0);
    });
  });

  group('events', () {
    test('durations and dots', () {
      final voice = parseSong('RH: C4w D4h E4 F4e G4.').rh!;
      expect(voice.map((e) => e.value), [
        NoteValue.semibreve,
        NoteValue.minim,
        NoteValue.crotchet,
        NoteValue.quaver,
        NoteValue.crotchet,
      ]);
      expect(voice.last.dotted, isTrue);
      expect(voice.last.ticks, 36); // a dotted crotchet
    });

    test('chords are bracketed, rests are R', () {
      final voice = parseSong('RH: [C4 E4 G4]w Rh').rh!;
      expect(voice.first.midiNotes, [60, 64, 67]);
      expect(voice.first.value, NoteValue.semibreve);
      expect(voice.last.isRest, isTrue);
      expect(voice.last.value, NoteValue.minim);
    });

    test('barlines and whitespace are optional separators', () {
      expect(parseSong('RH: | C4 D4 | E4 |').rh, hasLength(3));
      expect(parseSong('RH: C4 D4 E4').rh, hasLength(3));
    });

    test('either hand may be omitted', () {
      expect(parseSong('RH: C4').lh, isNull);
      expect(parseSong('LH: C3').rh, isNull);
      expect(parseSong('RH: C4').hands, {Hand.right});
    });

    test('repeated lines append to the same hand', () {
      expect(parseSong('RH: C4\nRH: D4\n').rh, hasLength(2));
    });

    test('a chord names itself when it spells one', () {
      final event = parseSong('RH: [C4 E4 G4]').rh!.first;
      expect(event.chordName, 'C');
      expect(event.label, '[C4 E4 G4]');
      // Below three distinct pitches there is no chord to name.
      expect(parseSong('RH: [C4 E4]').rh!.first.chordName, isNull);
    });
  });

  group('columns', () {
    test('hands merge onto one timeline, one column per onset', () {
      final song = parseSong('RH: C4 D4 E4 F4\nLH: [C3 G3]w\n');
      expect(song.columns, hasLength(4));
      expect(song.columns.first.rh!.midiNotes, [60]);
      expect(song.columns.first.lh!.midiNotes, [48, 55]);
      // The left hand's whole note only sounds at the first onset.
      expect(song.columns[1].lh, isNull);
    });

    test('a column landing on the bar grid is flagged', () {
      final song = parseSong('time: 4/4\nRH: C4 D4 E4 F4 G4\n');
      expect(song.columns.first.startsBar, isTrue);
      expect(song.columns[1].startsBar, isFalse);
      expect(song.columns[4].startsBar, isTrue);
    });

    test('a column knows what each hand is asked for', () {
      final song = parseSong('RH: C4\nLH: C3\n');
      expect(song.columns.first.notesFor(PlayHands.right), [60]);
      expect(song.columns.first.notesFor(PlayHands.left), [48]);
      expect(song.columns.first.notesFor(PlayHands.both), [60, 48]);
    });
  });

  group('malformed charts are reported, not crashed on', () {
    // Every one of these took v1 down with a RangeError, a null-check TypeError
    // or a backwards substring, from inside a fire-and-forget await.
    test('a bad letter inside a chord bracket', () {
      expect(
        () => parseSong('RH: [C4 X4]'),
        throwsA(isA<SongFormatException>()),
      );
    });

    test('a bad token on a voice line', () {
      expect(() => parseSong('RH: C4 wat'), throwsA(isA<SongFormatException>()));
    });

    test('an unterminated chord bracket', () {
      expect(
        () => parseSong('RH: [C4 E4'),
        throwsA(isA<SongFormatException>()),
      );
    });

    test('an empty chord bracket', () {
      expect(() => parseSong('RH: []'), throwsA(isA<SongFormatException>()));
    });

    test('a pitch with no octave', () {
      expect(() => parseSong('RH: C'), throwsA(isA<SongFormatException>()));
    });

    test('the error points at the line and token', () {
      try {
        parseSong('title: T\n\nRH: C4 D4\nLH: [C3 X3]\n');
        fail('expected a SongFormatException');
      } on SongFormatException catch (error) {
        expect(error.line, 4);
        expect(error.token, 'X3');
        expect(error.toString(), contains('line 4'));
      }
    });

    test('a double accidental is rejected rather than mis-parsed', () {
      // Unsupported throughout — better to say so than to draw a single sharp.
      expect(() => parseSong('RH: F##4'), throwsA(isA<SongFormatException>()));
    });
  });

  group('the bundled chart', () {
    test('parses, and every note is playable on an FP-30X', () async {
      final text = await _readAsset('assets/songs/stop_the_wedding.song');
      final song = parseSong(text);
      expect(song.title, isNotEmpty);
      expect(song.columns, isNotEmpty);

      for (final column in song.columns) {
        for (final hand in Hand.values) {
          for (final note in column.eventFor(hand)?.midiNotes ?? const <int>[]) {
            expect(
              note,
              inInclusiveRange(21, 108),
              reason: '$note is off the keyboard',
            );
          }
        }
      }
    });
  });
}

Future<String> _readAsset(String path) async {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsString();
}
