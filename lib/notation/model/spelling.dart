import '../../domain/models/music_key.dart';
import '../../domain/models/pitch.dart';

/// How black keys are spelled.
///
/// [conventional] names each isolated black key the common way;
/// [sharps]/[flats] force one accidental throughout; [Spelling.forKey] lets the
/// key answer it — its own notes take their scale letters and draw no
/// accidental (the signature has said it), anything outside the scale still
/// draws one.
enum SpellingKind { conventional, sharps, flats, key }

class Spelling {
  const Spelling._(this.kind, [this.key]);

  const Spelling.forKey(MusicKey key) : this._(SpellingKind.key, key);

  final SpellingKind kind;
  final MusicKey? key;

  static const conventional = Spelling._(SpellingKind.conventional);
  static const sharps = Spelling._(SpellingKind.sharps);
  static const flats = Spelling._(SpellingKind.flats);

  /// The spelling a key's own chords take: all sharps or all flats, never
  /// mixed, so a chord's letters agree with each other.
  static Spelling matching(MusicKey key) => switch (key.accidental) {
    Accidental.flat => flats,
    _ => sharps,
  };

  @override
  bool operator ==(Object other) =>
      other is Spelling && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);
}
