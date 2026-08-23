import 'game_mode.dart';
import 'music_key.dart';
import 'song.dart';

/// Knobs for a round, as chosen in the settings sheets and persisted between
/// launches.
class GameSettings {
  /// An empty [octaves] falls back to [defaultOctaves]: the note pool must
  /// never be empty, or a round would have nothing to deal.
  GameSettings({
    this.mode = GameMode.singleNote,
    Set<int>? octaves,
    this.durationSeconds = 180,
    this.untimed = false,
    this.chordKey = MusicKey.cMajor,
    this.songAsset,
    this.hands = PlayHands.right,
  }) : octaves = (octaves == null || octaves.isEmpty)
           ? defaultOctaves
           : octaves;

  static const defaultOctaves = {3, 4, 5};

  /// Octaves lying wholly inside the FP-30X's 21…108 range.
  static const octaveBounds = [1, 2, 3, 4, 5, 6, 7];
  static const minDuration = 30;
  static const maxDuration = 600;
  static const durationStep = 30;

  final GameMode mode;

  /// Octaves the target is drawn from. Never empty.
  final Set<int> octaves;
  final int durationSeconds;
  final bool untimed;

  /// Chords-in-key mode: the one key every chord is drawn from and spelled by.
  final MusicKey chordKey;

  /// Sheet-music mode: the selected song's asset path, or `null` if unchosen.
  final String? songAsset;

  /// Sheet-music mode: which hand(s) the player is graded on.
  final PlayHands hands;

  /// `null` is untimed, the one distinction the HUD and clock branch on.
  Duration? get timeLimit =>
      untimed || !mode.timed ? null : Duration(seconds: durationSeconds);

  /// The high-score bucket for this exact combination, or `null` when the round
  /// is not against the clock — infinite rounds are not saved.
  String? get highScoreKey {
    if (timeLimit == null) return null;
    final oct = (octaves.toList()..sort()).join('-');
    final bucket = '${mode.name}_${durationSeconds}_$oct';
    // Only chords-in-key varies by key, so every other mode's saved buckets
    // keep the names they already have.
    return mode.hasKnob(SettingKnob.chordKey)
        ? '${bucket}_${chordKey.fifths}${chordKey.tonality.name}'
        : bucket;
  }

  GameSettings copyWith({
    GameMode? mode,
    Set<int>? octaves,
    int? durationSeconds,
    bool? untimed,
    MusicKey? chordKey,
    String? songAsset,
    PlayHands? hands,
  }) {
    return GameSettings(
      mode: mode ?? this.mode,
      octaves: octaves ?? this.octaves,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      untimed: untimed ?? this.untimed,
      chordKey: chordKey ?? this.chordKey,
      songAsset: songAsset ?? this.songAsset,
      hands: hands ?? this.hands,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.mode == mode &&
      other.durationSeconds == durationSeconds &&
      other.untimed == untimed &&
      other.chordKey == chordKey &&
      other.songAsset == songAsset &&
      other.hands == hands &&
      other.octaves.length == octaves.length &&
      other.octaves.containsAll(octaves);

  @override
  int get hashCode => Object.hash(
    mode,
    Object.hashAllUnordered(octaves),
    durationSeconds,
    untimed,
    chordKey,
    songAsset,
    hands,
  );
}
