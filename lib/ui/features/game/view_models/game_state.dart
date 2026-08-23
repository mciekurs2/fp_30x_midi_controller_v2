import '../../../../notation/model/score.dart';

enum GamePhase { idle, playing, finished }

/// The outcome of the most recent graded press, for the verdict overlay.
enum Verdict { hit, miss }

/// A round as the screen sees it.
///
/// Everything the staff draws is resolved here rather than in the widget: which
/// score, which column, which held keys read as the attempt and which of them
/// count. The view has no mode branches left, so a new game mode changes
/// nothing above this line.
class GameState {
  GameState({
    required this.staff,
    this.phase = GamePhase.idle,
    this.score = 0,
    this.remaining,
    this.cursor = 0,
    this.gradedColumn = 0,
    this.played = const {},
    this.correct = const {},
    this.scored = const {},
    this.hits = 0,
    this.misses = 0,
    this.verdict,
    this.error,
  });

  final GamePhase phase;
  final int score;

  /// `null` is untimed.
  final Duration? remaining;

  /// What to draw, and where in it we are.
  final Score staff;
  final int cursor;

  /// The column the last hit completed — where the keys that scored it stay
  /// pinned while they are held.
  final int gradedColumn;

  /// The live attempt: keys held that have not already scored.
  final Set<int> played;

  /// Which held keys count as right — the target's own notes plus anything
  /// already scored and not yet released.
  final Set<int> correct;

  /// Keys that scored and are still down. Letting go is what clears them, not
  /// the target moving on.
  final Set<int> scored;

  /// Graded presses, for the verdict overlay's re-fire tick.
  final int hits;
  final int misses;
  final Verdict? verdict;

  /// Why a round could not start, if it could not — a chart that will not parse
  /// is the realistic case. Shown rather than dropped.
  final String? error;

  bool get isRunning => phase == GamePhase.playing;

  GameState copyWith({
    GamePhase? phase,
    int? score,
    Duration? remaining,
    Score? staff,
    int? cursor,
    int? gradedColumn,
    Set<int>? played,
    Set<int>? correct,
    Set<int>? scored,
    int? hits,
    int? misses,
    Verdict? verdict,
    String? error,
  }) => GameState(
    phase: phase ?? this.phase,
    score: score ?? this.score,
    remaining: remaining ?? this.remaining,
    staff: staff ?? this.staff,
    cursor: cursor ?? this.cursor,
    gradedColumn: gradedColumn ?? this.gradedColumn,
    played: played ?? this.played,
    correct: correct ?? this.correct,
    scored: scored ?? this.scored,
    hits: hits ?? this.hits,
    misses: misses ?? this.misses,
    verdict: verdict ?? this.verdict,
    error: error,
  );
}
