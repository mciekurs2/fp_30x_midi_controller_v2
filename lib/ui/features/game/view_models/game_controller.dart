import 'dart:async';
import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers.dart';
import '../../../../domain/exercises/exercise.dart';
import '../../../../domain/exercises/exercise_factory.dart';
import '../../../../domain/models/game_mode.dart';
import '../../../../domain/models/note_event.dart';
import 'game_settings_controller.dart';
import 'game_state.dart';
import 'high_scores.dart';
import 'note_source.dart';

part 'game_controller.g.dart';

/// Ticks well below a second so the last one does not appear to hang.
const _tick = Duration(milliseconds: 100);

/// Runs a round: deals an [Exercise], feeds it the note stream, keeps the clock,
/// and records the score when it ends.
///
/// It knows nothing about any particular mode — dealing and grading both go
/// through [Exercise], so this file does not change when one is added.
@Riverpod(keepAlive: true)
class GameController extends _$GameController {
  Exercise? _exercise;
  StreamSubscription<NoteEvent>? _notes;
  Timer? _timer;

  /// Keys that scored and have not been released. They are kept out of the next
  /// target's attempt but stay drawn as right until let go of.
  final _spent = <int>{};

  /// The bucket this round counts toward, snapshotted at the start so a
  /// mid-round settings edit cannot move the goalposts.
  String? _scoreKey;

  /// Guards a second Play tap while a chart is still loading.
  bool _starting = false;

  @override
  GameState build() {
    ref.onDispose(() {
      _notes?.cancel();
      _timer?.cancel();
    });
    // Held keys are shown between rounds too, so the stream is watched
    // whether or not one is running.
    ref.listen(noteSourceProvider, (_, _) => _refreshStaff());
    return GameState(staff: idleScore(ref.read(gameSettingsControllerProvider)));
  }

  void toggle() => state.isRunning ? stop() : unawaited(start());

  void stop() => _finish();

  Future<void> start() async {
    if (state.isRunning || _starting) return;
    _starting = true;
    try {
      final settings = ref.read(gameSettingsControllerProvider);
      // Awaited, not read: reading a future that has not resolved is what made
      // v1's very first Play in sheet-music mode silently do nothing.
      final song = settings.mode == GameMode.song
          ? await ref.read(songRepositoryProvider).load(settings.songAsset)
          : null;
      if (!ref.mounted || state.isRunning) return;

      final exercise = createExercise(
        settings,
        random: ref.read(entropyProvider),
        song: song,
      );
      if (exercise == null) {
        state = state.copyWith(error: _cannotStart(settings.mode));
        return;
      }

      _exercise = exercise;
      _scoreKey = settings.highScoreKey;
      _spent.clear();

      state = GameState(
        phase: GamePhase.playing,
        remaining: settings.timeLimit,
        staff: exercise.score,
        cursor: exercise.cursor,
        // Hits and misses carry across rounds; the score does not.
        hits: state.hits,
        misses: state.misses,
      );
      _refreshStaff();

      await _notes?.cancel();
      _notes = ref.read(noteSourceProvider.notifier).events.listen(_onEvent);
      _startTimer(settings.timeLimit);
    } finally {
      _starting = false;
    }
  }

  /// What a "Play note" test tap should press to make progress.
  List<int> currentTargets() => _exercise?.required.toList() ?? const [];

  void _onEvent(NoteEvent event) {
    if (!state.isRunning) return;
    final exercise = _exercise;
    if (exercise == null) return;

    // A key that already scored is never graded a second time. A chord can
    // reach the stream as one batch — every press lands in the held set before
    // the first is delivered — so the press that completes it scores the whole
    // chord, and the presses queued behind it would otherwise be graded against
    // the *next* target and counted as misses.
    if (event case NotePressed(:final note) when !_spent.contains(note)) {
      final held = _heldKeys();
      switch (exercise.grade(pressed: note, held: held)) {
        case Hit(:final scored):
          _spent.addAll(scored);
          state = state.copyWith(
            score: state.score + 1,
            hits: state.hits + 1,
            verdict: Verdict.hit,
          );
          if (exercise.isFinished) {
            _finish();
            return;
          }
        case Miss():
          state = state.copyWith(
            misses: state.misses + 1,
            verdict: Verdict.miss,
          );
        case Pending():
          break;
      }
    }
    _refreshStaff();
  }

  /// Resolves everything the staff draws from the exercise and the keys down,
  /// so the view itself has nothing to work out.
  void _refreshStaff() {
    final held = _heldKeys();
    _spent.retainWhere(held.contains);

    final exercise = _exercise;
    if (!state.isRunning || exercise == null) {
      state = state.copyWith(
        staff: idleScore(
          ref.read(gameSettingsControllerProvider),
          lowestHeld: held.isEmpty ? null : held.reduce(math.min),
        ),
        played: const {},
        correct: const {},
        scored: const {},
      );
      return;
    }

    final scored = held.intersection(_spent);
    state = state.copyWith(
      staff: exercise.score,
      cursor: exercise.cursor,
      gradedColumn: exercise.gradedColumn,
      played: exercise.attemptFrom(held.difference(scored)),
      correct: {...exercise.required, ...scored},
      scored: scored,
    );
  }

  Set<int> _heldKeys() => ref.read(noteSourceProvider).keys.toSet();

  void _startTimer(Duration? limit) {
    _timer?.cancel();
    _timer = null;
    if (limit == null) return; // self-paced

    final clock = ref.read(clockProvider);
    final deadline = clock.now().add(limit);
    _timer = clock.periodic(_tick, (_) {
      final left = deadline.difference(clock.now());
      if (left > Duration.zero) {
        state = state.copyWith(remaining: left);
        return;
      }
      state = state.copyWith(remaining: Duration.zero);
      _finish();
    });
  }

  /// A phase of its own, not a return to idle, so the final score and clock stay
  /// on screen.
  void _finish() {
    _timer?.cancel();
    _timer = null;
    _notes?.cancel();
    _notes = null;
    _spent.clear();

    if (_scoreKey case final key? when state.score > 0) {
      ref.read(highScoresProvider.notifier).record(key, state.score);
    }
    _exercise = null;

    state = GameState(
      phase: GamePhase.finished,
      score: state.score,
      remaining: state.remaining,
      staff: idleScore(ref.read(gameSettingsControllerProvider)),
      hits: state.hits,
      misses: state.misses,
    );
    _refreshStaff();
  }

  String _cannotStart(GameMode mode) => mode == GameMode.song
      ? 'No playable song — check the chart parses.'
      : 'Nothing to play with these settings.';
}
