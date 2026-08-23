import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fp_30x_midi_controller_v2/data/parsing/song_parser.dart';
import 'package:fp_30x_midi_controller_v2/domain/exercises/chord_exercise.dart';
import 'package:fp_30x_midi_controller_v2/domain/exercises/exercise.dart';
import 'package:fp_30x_midi_controller_v2/domain/exercises/exercise_factory.dart';
import 'package:fp_30x_midi_controller_v2/domain/exercises/single_note_exercise.dart';
import 'package:fp_30x_midi_controller_v2/domain/exercises/song_exercise.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/chord.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/game_mode.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/game_settings.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/music_key.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/song.dart';

/// Plays [presses] in order, holding each down, and returns every verdict.
List<GradeResult> play(Exercise exercise, List<int> presses) {
  final held = <int>{};
  return [
    for (final note in presses)
      () {
        held.add(note);
        return exercise.grade(pressed: note, held: held);
      }(),
  ];
}

void main() {
  group('single note', () {
    SingleNoteExercise drill({int first = 60}) => SingleNoteExercise(
      octaves: const {3, 4, 5},
      random: Random(1),
      first: first,
    );

    test('the asked-for key scores and the target moves on', () {
      final exercise = drill();
      final result = exercise.grade(pressed: 60, held: {60});
      expect(result, isA<Hit>());
      expect((result as Hit).scored, {60});
      expect(exercise.target, isNot(60));
    });

    test('any other key misses and the target stays put', () {
      final exercise = drill();
      expect(exercise.grade(pressed: 61, held: {61}), isA<Miss>());
      expect(exercise.target, 60);
    });

    test('the new target is never the one just answered', () {
      final exercise = drill();
      var previous = exercise.target;
      for (var i = 0; i < 50; i++) {
        exercise.grade(pressed: previous, held: {previous});
        expect(exercise.target, isNot(previous));
        previous = exercise.target;
      }
    });

    test('only the lowest unspent key reads as the attempt', () {
      final exercise = drill();
      expect(exercise.attemptFrom({67, 60, 64}), {60});
      expect(exercise.attemptFrom(const {}), isEmpty);
    });

    test('the staff shows the target, named', () {
      final exercise = drill(first: 61);
      final voice = exercise.score.columns.single.voices.single!;
      expect(voice.midiNotes, [61]);
      expect(voice.label, 'C#4');
    });
  });

  group('chords', () {
    ChordExercise drill({ChordSource source = const AnyChordSource()}) =>
        ChordExercise(
          octaves: const {4},
          source: source,
          random: Random(1),
          first: const Chord(60, ChordQuality.major), // C E G
        );

    test('a hit lands the moment every note is held, in any order', () {
      final exercise = drill();
      final results = play(exercise, [67, 60, 64]);
      expect(results[0], isA<Pending>());
      expect(results[1], isA<Pending>());
      expect(results[2], isA<Hit>());
      expect((results[2] as Hit).scored, {60, 64, 67});
    });

    test('a key outside the chord misses but leaves progress intact', () {
      final exercise = drill();
      final held = <int>{60, 64};
      expect(exercise.grade(pressed: 61, held: {...held, 61}), isA<Miss>());
      held.add(61);
      held.add(67);
      // The two right notes still count: the chord completes as normal.
      expect(exercise.grade(pressed: 67, held: held), isA<Hit>());
    });

    test('the chord moves on after a hit', () {
      final exercise = drill();
      play(exercise, [60, 64, 67]);
      expect(exercise.chord, isNot(const Chord(60, ChordQuality.major)));
    });

    test('chords are spelled from their own key, never mixed', () {
      final exercise = ChordExercise(
        octaves: const {4},
        source: const AnyChordSource(),
        random: Random(1),
        first: const Chord(66, ChordQuality.major), // Gb, not F#
      );
      expect(exercise.score.columns.single.voices.single!.label, 'Gb');
      expect(exercise.score.signatureKey, isNull);
    });

    test('in-key chords draw a signature and are named by that key', () {
      const bMajor = MusicKey(fifths: 5, tonality: .major);
      final exercise = ChordExercise(
        octaves: const {4},
        source: const KeyChordSource(bMajor),
        random: Random(1),
        // The V of B major reads F#, where the chord's own key would say Gb.
        first: const Chord(66, ChordQuality.major),
      );
      expect(exercise.score.signatureKey, bMajor);
      expect(exercise.score.columns.single.voices.single!.label, 'F#');
    });

    test('every in-key chord is diatonic, so nothing draws an accidental', () {
      const eFlat = MusicKey(fifths: -3, tonality: .major);
      final exercise = ChordExercise(
        octaves: const {4},
        source: const KeyChordSource(eFlat),
        random: Random(7),
      );
      for (var i = 0; i < 40; i++) {
        for (final note in exercise.chord.notes) {
          expect(
            eFlat.contains(note % 12),
            isTrue,
            reason: '${exercise.chord} leaves ${eFlat.name}',
          );
        }
        play(exercise, exercise.chord.notes);
      }
    });
  });

  group('sheet music', () {
    final song = parseSong('''
title: Test
key: C major
time: 4/4

RH: | C4 R D4 | E4h |
LH: | [C3 G3]w | [B2 G3]w |
''');

    test('holding a column advances to the next onset the hand plays', () {
      final exercise = SongExercise(song: song, hands: PlayHands.right);
      final start = exercise.cursor;
      expect(exercise.required, {60});
      expect(exercise.grade(pressed: 60, held: {60}), isA<Hit>());
      expect(exercise.cursor, greaterThan(start));
      expect(exercise.gradedColumn, start);
    });

    test('rests and the other hand\'s columns are skipped', () {
      final exercise = SongExercise(song: song, hands: PlayHands.right);
      final visited = <int>[exercise.cursor];
      while (!exercise.isFinished) {
        final wanted = exercise.required;
        expect(wanted, isNotEmpty, reason: 'cursor parked on a rest');
        exercise.grade(pressed: wanted.first, held: wanted);
        if (!exercise.isFinished) visited.add(exercise.cursor);
      }
      // Every column the cursor stopped at asks the right hand for something.
      expect(visited, isNotEmpty);
    });

    test('a note the skipped hand shows is neither progress nor a mistake', () {
      final exercise = SongExercise(song: song, hands: PlayHands.right);
      // C3 and G3 belong to the left hand, which is not being graded.
      expect(exercise.grade(pressed: 48, held: {48}), isA<Pending>());
      // A key neither hand is showing does miss.
      expect(exercise.grade(pressed: 61, held: {48, 61}), isA<Miss>());
    });

    test('the round finishes when the cursor runs off the end', () {
      final exercise = SongExercise(song: song, hands: PlayHands.both);
      var guard = 0;
      while (!exercise.isFinished && guard++ < 100) {
        exercise.grade(
          pressed: exercise.required.first,
          held: exercise.required,
        );
      }
      expect(exercise.isFinished, isTrue);
      expect(exercise.required, isEmpty);
      // Grading past the end is inert rather than an error.
      expect(exercise.grade(pressed: 60, held: {60}), isA<Pending>());
    });

    test('both hands must be held together when both are graded', () {
      final exercise = SongExercise(song: song, hands: PlayHands.both);
      final wanted = exercise.required;
      expect(wanted.length, greaterThan(1));
      expect(
        exercise.grade(pressed: wanted.first, held: {wanted.first}),
        isA<Pending>(),
      );
      expect(exercise.grade(pressed: wanted.last, held: wanted), isA<Hit>());
    });
  });

  group('factory', () {
    test('every mode deals an exercise', () {
      for (final mode in GameMode.values) {
        final exercise = createExercise(
          GameSettings(mode: mode),
          random: Random(1),
          song: parseSong('title: T\nRH: C4 D4\n'),
        );
        expect(exercise, isNotNull, reason: 'no exercise for ${mode.name}');
        expect(exercise!.required, isNotEmpty);
      }
    });

    test('sheet music with no readable chart deals nothing', () {
      final exercise = createExercise(
        GameSettings(mode: GameMode.song),
        random: Random(1),
      );
      expect(exercise, isNull);
    });

    test('the idle staff shows the lowest held key', () {
      final score = idleScore(GameSettings(), lowestHeld: 55);
      expect(score.columns.single.midiNotes, [55]);
      expect(idleScore(GameSettings()).columns, isEmpty);
    });

    test('chords-in-key shows its signature before Play is pressed', () {
      const dMajor = MusicKey(fifths: 2, tonality: .major);
      final score = idleScore(
        GameSettings(mode: GameMode.keyChords, chordKey: dMajor),
      );
      expect(score.signatureKey, dMajor);
      expect(score.drawnSignature, dMajor);
    });
  });
}
