/// A key going down or coming up, from real MIDI or the test controls alike.
sealed class NoteEvent {
  const NoteEvent(this.note);
  final int note;
}

class NotePressed extends NoteEvent {
  const NotePressed(super.note, this.velocity);
  final int velocity;
}

class NoteReleased extends NoteEvent {
  const NoteReleased(super.note);
}
