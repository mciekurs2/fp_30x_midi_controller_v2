import '../../notation/model/score.dart';

/// What a graded press amounted to.
sealed class GradeResult {
  const GradeResult();
}

/// The exercise moved on. [scored] are the keys that earned it — drawn as right
/// until they are let go of, and not counted again towards the next target.
class Hit extends GradeResult {
  const Hit({this.scored = const {}});

  final Set<int> scored;
}

/// A wrong key.
class Miss extends GradeResult {
  const Miss();
}

/// Right so far, but not the whole answer yet — neither scored nor punished.
/// Half a chord sits here until its last note goes down.
class Pending extends GradeResult {
  const Pending();
}

/// One kind of drill. Everything a game mode does differently lives behind this
/// interface: what it asks for, how it draws it, how it grades a press, and when
/// it runs out.
///
/// Adding a mode is a new implementation plus a branch in
/// `exercise_factory.dart` — the controller, the staff, the HUD and the settings
/// sheet are all untouched.
abstract class Exercise {
  /// What the staff draws. Rebuilt when the target changes, so identity is
  /// enough for the view to know something moved.
  Score get score;

  /// Which column of [score] is being asked for.
  int get cursor => 0;

  /// The column the last hit completed. Its keys stay pinned there while they
  /// are held, rather than snapping onto the new target.
  int get gradedColumn => 0;

  /// The keys that must be held to advance.
  Set<int> get required;

  /// Whether there is nothing left to ask.
  bool get isFinished => false;

  /// Which of the keys held — and not already spent — read as the live attempt.
  /// Most exercises show them all; a single-note drill shows only the lowest,
  /// so a resting hand does not clutter the staff.
  Set<int> attemptFrom(Set<int> unspent) => unspent;

  /// Grades [pressed] against everything currently [held], and — on a hit —
  /// moves to the next target.
  GradeResult grade({required int pressed, required Set<int> held});
}
