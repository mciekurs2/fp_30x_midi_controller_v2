# fp_30x_midi_controller_v2

A piano training game for the Roland FP-30X, over Bluetooth MIDI. The app puts a note, a chord
or a piece of sheet music on a staff and you score by playing it on the piano.

Four modes: **single note**, **chords**, **chords in key** (drawn under a key signature), and
**sheet music** (self-paced, from hand-written `.song` charts).

## Running it

```bash
flutter pub get
dart run build_runner build
flutter run -d <device>
```

Debug builds include a **Play note** button that simulates a keypress aimed at the current
target, so every mode can be played through without the piano.

See `CLAUDE.md` for the architecture, the `.song` format, and how to add a game mode.
