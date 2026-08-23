/// A knob a mode's settings sheet offers. The sheet is built from these rather
/// than from a branch per mode, so a new mode picks its controls by listing
/// them here.
enum SettingKnob { duration, octaves, chordKey, song, hands }

/// What the mode picker offers. Adding a value here makes the exercise factory
/// (`domain/exercises/exercise_factory.dart`) fail to compile until the new
/// mode is dealt — which is the point.
enum GameMode {
  singleNote('Single note', {SettingKnob.duration, SettingKnob.octaves}),
  chords('Chords', {SettingKnob.duration, SettingKnob.octaves}),
  keyChords('Chords in key', {
    SettingKnob.duration,
    SettingKnob.octaves,
    SettingKnob.chordKey,
  }),
  song('Sheet music', {SettingKnob.song, SettingKnob.hands}, timed: false);

  const GameMode(this.title, this.knobs, {this.timed = true});

  final String title;
  final Set<SettingKnob> knobs;

  /// Whether a round runs against the clock. A piece is self-paced, so sheet
  /// music has no time limit and records no high score.
  final bool timed;

  bool hasKnob(SettingKnob knob) => knobs.contains(knob);
}
