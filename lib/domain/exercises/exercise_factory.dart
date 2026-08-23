import 'dart:math';

import '../../notation/model/score.dart';
import '../../notation/model/spelling.dart';
import '../models/game_mode.dart';
import '../models/game_settings.dart';
import '../models/song.dart';
import 'chord_exercise.dart';
import 'exercise.dart';
import 'single_note_exercise.dart';
import 'song_exercise.dart';

/// Deals the exercise [settings] asks for, or `null` when it cannot be dealt —
/// sheet music with no readable chart, or a pool too narrow for a chord.
///
/// Adding a [GameMode] makes this switch non-exhaustive, which is the compiler
/// telling you the one place a new mode has to be wired in.
Exercise? createExercise(
  GameSettings settings, {
  required Random random,
  Song? song,
}) {
  return switch (settings.mode) {
    GameMode.singleNote => SingleNoteExercise(
      octaves: settings.octaves,
      random: random,
    ),
    GameMode.chords => _chords(settings, const AnyChordSource(), random),
    GameMode.keyChords => _chords(
      settings,
      KeyChordSource(settings.chordKey),
      random,
    ),
    GameMode.song => switch (song) {
      null => null,
      final chart => SongExercise(song: chart, hands: settings.hands),
    },
  };
}

/// What the staff shows between rounds: the lowest key under your hand, drawn
/// the way the chosen mode would write it.
///
/// Chords-in-key draws its signature here too, so the key is on screen before
/// Play is ever pressed — reading it is the point of the mode.
Score idleScore(GameSettings settings, {int? lowestHeld}) {
  final notes = [?lowestHeld];
  return switch (settings.mode) {
    GameMode.keyChords => Score.chord(
      notes,
      spelling: Spelling.forKey(settings.chordKey),
      signatureKey: settings.chordKey,
    ),
    _ => Score.chord(notes),
  };
}

ChordExercise? _chords(
  GameSettings settings,
  ChordSource source,
  Random random,
) {
  final first = source.next(settings.octaves, random);
  if (first == null) return null;
  return ChordExercise(
    octaves: settings.octaves,
    source: source,
    random: random,
    first: first,
  );
}
