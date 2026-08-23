import '../../domain/models/song.dart';
import '../layout/glyph.dart';

enum Clef {
  treble(MusicSymbol.gClef, -1, 71), // middle line B4
  bass(MusicSymbol.fClef, 1, 50); // middle line D3

  const Clef(this.symbol, this.origin, this.middleLineNote);

  final MusicSymbol symbol;

  /// The line the clef names, as a step from the middle line.
  final double origin;

  /// The pitch sitting on the middle staff line.
  final int middleLineNote;

  /// A signature sits two steps lower in the bass clef than in the treble.
  int get signatureDrop => this == Clef.treble ? 0 : -2;

  /// The clef a note — or a chord's lowest note — is drawn in.
  static Clef forNote(int midiNote) => midiNote >= 60 ? treble : bass;

  /// The staff a hand is written on.
  static Clef forHand(Hand hand) => hand == Hand.right ? treble : bass;
}
