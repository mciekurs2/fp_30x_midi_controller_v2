import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/chord.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/music_key.dart';

/// Every key, both tonalities.
Iterable<MusicKey> get _allKeys sync* {
  for (var pitchClass = 0; pitchClass < 12; pitchClass++) {
    yield MusicKey.major(pitchClass);
    yield MusicKey.minor(pitchClass);
  }
}

/// The distinct chords `randomChordInKey` can return, found by exhausting it —
/// the pool is small and the function is the only way in.
Set<Chord> _poolFor(MusicKey key, Set<int> octaves) {
  final random = Random(7);
  return {for (var i = 0; i < 500; i++) randomChordInKey(octaves, key, random)!};
}

void main() {
  group('randomChordInKey', () {
    test('deals only chords that fit the key', () {
      for (final key in _allKeys) {
        for (final chord in _poolFor(key, {4})) {
          for (final note in chord.notes) {
            expect(
              key.contains(note % 12),
              isTrue,
              reason: '${chord.nameIn(key)} leaves ${key.name}',
            );
          }
        }
      }
    });

    test('leaves six shapes per key — the 7th degree fits neither quality', () {
      for (final key in _allKeys) {
        expect(_poolFor(key, {4}).length, 6, reason: key.name);
      }
    });

    test('deals the same six shapes in every selected octave', () {
      expect(_poolFor(MusicKey.major(7), {3, 4, 5}).length, 18);
    });

    test('names G major its six triads', () {
      final g = MusicKey.major(7);
      final names = {for (final chord in _poolFor(g, {4})) chord.nameIn(g)};
      expect(names, {'G', 'Am', 'Bm', 'C', 'D', 'Em'});
    });

    test('names C minor its six triads', () {
      final key = MusicKey.minor(0);
      final names = {for (final chord in _poolFor(key, {4})) chord.nameIn(key)};
      expect(names, {'Cm', 'Eb', 'Fm', 'Gm', 'Ab', 'Bb'});
    });

    test('avoids repeating the chord just played', () {
      final random = Random(3);
      const chord = Chord(60, ChordQuality.major);
      for (var i = 0; i < 50; i++) {
        expect(
          randomChordInKey({4}, MusicKey.major(0), random, avoiding: chord),
          isNot(chord),
        );
      }
    });

    test('is null with no octaves to root in', () {
      expect(randomChordInKey(const {}, MusicKey.cMajor, Random(1)), isNull);
    });
  });

  group('randomChord', () {
    test('deals only the two game triads by default', () {
      final random = Random(5);
      for (var i = 0; i < 200; i++) {
        expect(
          ChordQuality.gameQualities,
          contains(randomChord({3, 4}, random)!.quality),
        );
      }
    });

    test('the whole catalogue is available on request', () {
      final random = Random(5);
      final qualities = {
        for (var i = 0; i < 2000; i++)
          randomChord({4}, random, from: ChordQuality.values)!.quality,
      };
      expect(qualities.length, ChordQuality.values.length);
    });

    test('is null with no octaves to root in', () {
      expect(randomChord(const {}, Random(1)), isNull);
    });
  });

  group('Chord.nameIn', () {
    test('spells the root by the chosen key, not the chord\'s own', () {
      // The V of B major. On its own the root is spelled Gb; in B major it is
      // written F#, a letter away from the line the notehead sits on.
      const chord = Chord(66, ChordQuality.major);
      expect(chord.name, 'Gb');
      expect(chord.nameIn(MusicKey.major(11)), 'F#');
    });

    test('falls back to the chord\'s own spelling outside the key', () {
      const chord = Chord(61, ChordQuality.major);
      expect(chord.nameIn(MusicKey.major(0)), chord.name);
    });
  });

  group('MusicKey.spell', () {
    test('writes a pitch with the key\'s own letter', () {
      expect(MusicKey.major(2).spell(1), 'C#'); // D major sharps its C
      expect(MusicKey.major(5).spell(10), 'Bb'); // F major flats its B
      expect(MusicKey.major(0).spell(0), 'C');
    });

    test('is null for a pitch the key has no letter for', () {
      expect(MusicKey.major(0).spell(1), isNull);
    });

    test('agrees with tonicName for every key', () {
      for (final key in _allKeys) {
        expect(key.spell(key.tonicPitchClass), key.tonicName);
      }
    });

    test('picks the spelling with six accidentals or fewer', () {
      for (final key in _allKeys) {
        expect(key.accidentalCount, lessThanOrEqualTo(6), reason: key.name);
      }
      // The F#/Gb tritone tie resolves to flats.
      expect(MusicKey.major(6).tonicName, 'Gb');
    });
  });
}
