import '../../notation/model/score.dart';
import '../models/song.dart';
import 'exercise.dart';

/// A piece of sheet music, self-paced: the cursor advances only as each onset is
/// landed, and the round runs until it falls off the end.
///
/// Graded like a chord at every onset — holding the active hand's notes moves
/// on, a stray key misses. A note belonging to the hand being *skipped* is
/// neither progress nor a mistake: it is on the staff, just not being asked for.
class SongExercise extends Exercise {
  SongExercise({required this.song, required this.hands})
    : _cursor = 0 {
    _cursor = _firstPlayable(0);
  }

  final Song song;
  final PlayHands hands;

  int _cursor;
  int _gradedColumn = 0;

  @override
  late Score score = Score.song(song, hands);

  @override
  int get cursor => _cursor;

  @override
  int get gradedColumn => _gradedColumn;

  @override
  bool get isFinished => _cursor >= song.columns.length;

  @override
  Set<int> get required => _notesAt(_cursor, active: true);

  @override
  GradeResult grade({required int pressed, required Set<int> held}) {
    if (isFinished) return const Pending();
    final wanted = required;
    if (wanted.isEmpty) return const Pending();

    if (held.containsAll(wanted)) {
      _gradedColumn = _cursor;
      _cursor = _firstPlayable(_cursor + 1);
      return Hit(scored: wanted);
    }
    if (wanted.contains(pressed) ||
        _notesAt(_cursor, active: false).contains(pressed)) {
      return const Pending();
    }
    return const Miss();
  }

  /// The notes at column [i] belonging to the hand(s) being graded, or — with
  /// [active] false — the ones the skipped hand shows but is not asked for.
  /// Empty for a rest.
  Set<int> _notesAt(int i, {required bool active}) {
    if (i < 0 || i >= song.columns.length) return const {};
    final column = song.columns[i];
    return {
      for (final hand in Hand.values)
        if (hands.plays(hand) == active)
          if (column.eventFor(hand) case final event? when !event.isRest)
            ...event.midiNotes,
    };
  }

  /// The first column at or after [from] the graded hand(s) actually play.
  int _firstPlayable(int from) {
    var i = from;
    while (i < song.columns.length && _notesAt(i, active: true).isEmpty) {
      i++;
    }
    return i;
  }
}
