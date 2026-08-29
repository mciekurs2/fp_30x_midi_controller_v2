# fp_30x_midi_controller_v2

## Coding rules

The official Flutter/Dart AI rules apply to all work in this repo:

@rules.md

State management is Riverpod 3 with code generation. Before writing or changing any provider,
notifier or `ref.*` call, load the `riverpod` skill (`.claude/skills/riverpod/SKILL.md`).

## Project

A stylized piano training game for the Roland FP-30X. It connects over **Bluetooth MIDI** and
turns played notes into exercises: the app puts a note on a staff and you score by pressing the
matching key.

**Target: mobile phone, portrait.** Layouts are checked at **360 × 640**, the narrowest phone
the app supports — and they must be checked *with* the app's own **1.5× text scale**, which is
applied globally in `main.dart` because JollyLodger is condensed and reads small. Three real
overflows were hiding behind tests that skipped that scale. The `GameHud` row is the
one deliberate exception: it keeps v1's `Spacer` layout and its 25 px overflow, pinned
by message in `home_page_test.dart` so every *other* overflow still fails.

This is a rewrite of `../fp_30x_midi_controller` (v1). v1 is the reference for **behaviour and
geometry** — the notation constants especially were copied across, not re-derived. The iOS
project v1 mentions is an early version and is **not** a reference for anything.

## Commands

```bash
flutter pub get
dart run build_runner build     # after adding or changing any @riverpod provider
dart run build_runner watch     # during development
flutter analyze                 # must be clean
flutter test
flutter run -d <device>         # android, ios, macos, windows (no linux/web)
```

`build_runner` 2.15 dropped `--delete-conflicting-outputs`; it is ignored if passed.

`*.g.dart` is committed, so a fresh clone builds without generating first.

## Architecture

Layered per `rules.md` and the `flutter-apply-architecture-best-practices` skill. Dependencies
run **`ui → domain → data`** and **`ui → notation`**. `notation/` never imports `ui/`; `domain/`
never imports Flutter's material library.

```
lib/
├── core/          clock.dart (a Clock seam), providers.dart (every service/repository)
├── data/
│   ├── services/     preferences, midi_device (BLE), song_asset — each behind an interface
│   ├── repositories/ settings, high_score, song
│   └── parsing/      song_parser.dart
├── domain/
│   ├── models/       pitch, music_key, chord, chord_identifier, song, note_value,
│   │                 note_event, game_mode, game_settings — pure Dart, no Flutter
│   └── exercises/    exercise.dart (the seam) + one file per mode + exercise_factory.dart
├── notation/
│   ├── model/        score.dart, clef, spelling, staff_placement
│   ├── layout/       glyph.dart (SMuFL metrics), staff_style.dart, score_layout.dart — pure
│   ├── painting/     glyph_cache, marks, score_painter
│   └── widgets/      staff_view.dart, staff_label.dart
└── ui/
    ├── core/         theme/app_theme.dart, widgets/sheet.dart
    └── features/     game/{view_models,views}, connection/views, debug/{view_models,views}
```

### The two seams

**`Exercise` (`domain/exercises/`)** is what a game mode *is*: what it asks for
(`required`), what the staff draws (`score`), and how it grades a press
(`grade` → `Hit` / `Miss` / `Pending`). `GameController` deals one and feeds it the note
stream; it knows nothing about any particular mode. `Random` is constructor-injected, so
dealing and grading are deterministic under test.

**`Score` (`notation/model/score.dart`)** is what the staff draws: staves, columns, voices, a
signature and a spelling. Notation knows nothing about targets, spent notes or grading — the
overlay reaches it as plain `Set<int>`. One `StaffView` renders every case: a one-column score
is centred and its notes drop in; a longer one flows and scrolls under a cursor.

### What the staff animates

Every layer `StaffView` draws sits in an `AnimatedSwitcher`, and the switcher decides whether
to animate by comparing child keys with `==`. **A key built from a `List` is never equal to the
last frame's**, so it replays the entry animation on every rebuild — and a keypress rebuilds
the staff, so the notes and clef would drop in again on every press, right or wrong. Keys name
what the layer *draws* (`_clefSignature`, `_columnSignature`, `_heldSignature`) and deliberately
leave colour out, so a wrong key turning right repaints in place instead of re-entering.

Held keys are drawn differently by alignment, following v1:

- **Centred** (single note, both chord modes) — the live attempt and the keys that already
  scored are *one* layer on the one column. They drop in and out together, and both take
  `layout.columnX`.
- **Flowing** (sheet music) — scored keys are pinned to the column they were struck at while
  the music scrolls past them, and neither layer animates. The scroll is the movement.

On a grand staff a held key takes **the stave whose voice actually wrote it** (`staveForNote`),
falling back to the middle-C split only for a key no voice asks for. The hands overlap in real
arrangements — `blue.song`'s right hand reaches down to B3 — and the split alone put a
correctly played right-hand note on the bass stave.

A key that scores keeps the **clef and spelling of the target it answered**, not the one on
screen now (`_lastTarget`). Grading deals the next target in the same event as the press, so
the staff never draws a frame with that key down under the target it was actually answering —
without the remembered writing the green note jumps clef or staff position the instant the next
target lands. A key the current column *asks for* is re-written its way, so one held from a
flat chord into a sharp one that wants it gets re-spelled rather than sitting a step off.

It keeps its **accidental column** the same way. `overlayColumns` deals the scored keys their
columns *before* the target's, so a fresh target's accidentals fit around a held green note
instead of shoving it left — v1 columned the target first and the green note jumped nearly two
columns when a flat chord landed. The target still never shifts as *live* keys go down: those
are fitted last. The cost is that releasing a scored key lets the target's accidentals close
up, which is invisible in play because scoring and the next target land in the same event.

The **name row follows the cursor, not the scroll.** `layout.base` is the animated scroll
position floored, so in sheet music it only reaches the new column when the 340 ms scroll
lands; reading it left the name a whole scroll behind the note it names. Centred modes have no
scroll, which is why only sheet music showed it.

Each hand's name row is captioned with **its own** chord, if its own notes spell one — the
staff never names a harmony across the hands. `blue.song`'s left hand is dyads throughout and
so goes unnamed, and the right hand's `[B3 D4 E4 G4]` reads `Em7/B` where the two hands
together are plainly `G6`. That is deliberate: the row names what the hand under it is being
asked to play, and a first-time reader has no use for the name of a chord neither hand holds.
The name and the chord share one line and one `TextSpan`, so they sit on a shared baseline,
and the row is `FittedBox`-scaled to one line: the block reserves the height of exactly one,
and `[B3 D4 E4 G4]  [Em7/B]` is wide enough to wrap on a 360 dp phone.

### How a chord is drawn

**A chord has one stem, not one per notehead** (`notation/layout/chord_layout.dart`). SMuFL
ships noteheads with the stem baked in, and drawing one per note gave a four-note chord four
stems — pointing *different ways* where it straddled the middle line, because the direction was
`steps >= 0` per note. So the notation draws bare noteheads (`noteheadBlack` and friends) and
places the stem itself. `layoutChord` decides, once, for the whole stack:

- **Direction** — the head furthest from the middle line wins; a tie hangs down.
- **Length** — measured from the head the stem *grows out of*, so a triad's tip lands about the
  middle line. A chord wider than `stemLength` lengthens to clear its far head by
  `stemOverhang` instead. Measuring a fixed reach past the *far* head, which is the tempting
  reading of the rule, sends an octave in the left hand a whole staff up.
- **Seconds** — two heads a diatonic step apart cannot share a side of the stem, so the second
  one crosses it: right of an up stem, left of a down one, sharing the stem rather than
  clearing it. A cluster alternates, and two heads on one step (F♮ beside F♯) split the same
  way. The displaced head widens the column, which is why `voiceExtent` measures through the
  chord rather than assuming one notehead's width.

The overlay **follows the target's chord** the way it follows its accidental columns
(`layoutChord(..., follow:)`): a held key takes the target's stem direction and the exact
offset of any step the target writes, so a green head lands on the very notehead it is
answering instead of half a head-width beside it. Its stem takes the *written* tip — an overlay
reaching its own nominal length would shoot past the stem underneath the moment a chord's top
note alone went down — but its own head as the foot, so only the stem the keys actually down
reach along is tinted.

`staffHalfGap` was widened from 3 to 4 for the same reason: at 3 a bass chord's stem reaching
up met a treble note hanging below its staff, and the two read as one line through the system.

### Adding a game mode

1. Add the value to `GameMode`, listing the `SettingKnob`s its settings sheet should offer.
2. Implement `Exercise` in a new file under `domain/exercises/`.
3. Deal it in `createExercise` — the switch is exhaustive, so the compiler will not let you
   forget. Add an `idleScore` branch only if it needs one.
4. Add its icon to `_iconFor` in `game_controls.dart`, and a settings widget only if it needs a
   knob no other mode has.

Nothing else changes: not the controller, not the staff, not the HUD, not the sheet. (In v1
this was a ten-site edit with no compiler help.)

### Data flow

`MidiDeviceService.notes` (real BLE) **or** `NoteSource.play()` (the debug controls) → one
`NoteSource` stream → `GameController` grades through the active `Exercise` and resolves
everything the staff draws → `GameStaffView`/`GameHud` render. One stream drives grading and
display alike, which is what makes the game fully playable without a piano.

Delivery lags the held set: the stream is broadcast, so a chord that arrives as one batch — a
BLE packet carrying several messages, or the debug controls' Play note button — has every key
in `NoteSource` state before the first press reaches `GameController`. **A key already in
`_spent` is never graded again.** Without that, the press completing a chord scores the whole
thing and the two behind it are graded against the *next* target and counted as misses: one
right chord, one hit and two misses. `misses` is drawn nowhere but `VerdictMark`, so the only
symptom was a cross over a chord you played correctly.

### Persistence

`shared_preferences` behind `PreferencesService`, under the key prefixes `gamesettings_` and
`highscore_`. Every read is defensive: an unrecognised enum name, an unparseable integer or an
empty octave set falls back to a default rather than throwing during startup. A value that is
no longer *offered* falls back the same way — `hands` is read against `PlayHands.offered`, not
`.values`, so an install that chose dual-hand before it was withheld does not keep playing it.

## The `.song` format (`assets/songs/`)

Hand-edited — there is no in-app editor, and the workflow is transcribing a photographed score.

```
title: Ode to Joy
key: D major          # drives the signature AND the implicit accidentals
time: 4/4             # bar grid only; not drawn, not graded
barlines: off         # optional — suppress the bar divisions entirely

RH: | F4 F4 G4 A4 | A4 G4 F4 E4 |     # F4 sounds F#4 — the signature says so
LH: | [D3 A3]w | [A2 E3]w |           # chords bracketed; w = whole note
```

- **Header** until the first voice line: `title`, `key` (`D major` / `B minor`), `time`, and
  `barlines` (`off`/`no`/`none`/`false`).
- **`RH:` / `LH:`** — one hand each, either may be omitted. Repeated lines append.
- **Pitch** `C4` (middle C = MIDI 60). Accidentals are **key-implicit**: write one (`F#4`,
  `Eb3`, `Fn4` for a natural) only to *depart* from the signature.
- **Chords** `[C4 E4 G4]`; **rests** `R`; **durations** suffix `w`/`h`/`q`/`e` (default
  quarter), trailing `.` dots it.
- `|` and whitespace are optional separators; the written `|` is cosmetic.
- A malformed chart raises `SongFormatException` with the line and token, and
  `SongRepository` leaves it out of the library rather than taking a round down with it.
- **Double accidentals are unsupported** and are rejected by the parser rather than
  mis-parsed.

`blue.song` is a **hybrid arrangement**, and the pattern is worth reusing: the left hand is
transcribed as written, and the right hand is thinned to only the notes sounding at each
left-hand strike. A published piano-vocal arrangement's right hand is a sung melody in
sixteenths against a half-note bass — unplayable as a reading drill, and it leaves most
columns with one hand on them. Thinning it puts both hands on every column, which is what
makes `PlayHands.both` playable. `song_parser_test.dart` guards that invariant.

## Conventions

- **Comment sparingly.** Self-explanatory code needs no prose. Comment the genuinely
  non-obvious: *why* a choice was made, a subtle gotcha, a ported geometry constant. Prefer a
  clear name over a comment. Do not narrate widget structure.
- **`@Riverpod(keepAlive: true)` for session state read imperatively via `.notifier`.** An
  auto-disposing provider resets to defaults the moment nothing watches it — a real bug in v1's
  settings.
- **Enum dot-shorthands** (`.min`, `.center`, `.fromLTRB(...)`) are used throughout. Match the
  surrounding style.
- **Notation geometry is copied from v1, not re-derived.** `staffScale = 330`,
  `headroom = 3.93` and the rest of `StaffMetrics` are load-bearing. `labelDrop` /
  `labelDropGrand` are the exception — tuned by eye for this app, and the knob to reach for
  when the name row wants moving. `stemLength` / `stemOverhang` / `staffHalfGap` are this
  app's own, added with drawn stems — see *How a chord is drawn*. Express any such tweak in staff spaces there, never as raw
  pixels at the call site: `staffSpace` is what the whole notation scales by.
- **Layout changes need a 360 dp widget test** that applies `withTextScale`, or an overflow
  will not be caught.
- **`AnimatedSwitcher` keys must be value-equal.** Never key one on a `List`, a `Set` or a
  freshly-built object — see *What the staff animates*. `staff_view_test.dart` guards this by
  counting painters mid-frame.

## Not yet ported (deliberately)

`blue.song` covers bars 1–20 only. From bar 21 the left hand drops its block chords for a
running single-note riff, which the hybrid rule has nothing to thin against; the photographed
pages for the rest are in `song_pngs/`.

Also unported: a single-note version of the key-signature drill (the notation is all there
— chords-in-key uses it — it just is not a `GameMode`). Chord **variations** beyond major/minor
triads as exercise targets: `chord_identifier` already recognises the full catalogue, but the
chords mode deals root-position triads only.

For sheet music: real **timing/tempo** (durations are encoded and drawn, but nothing is graded
on rhythm — rounds are self-paced by design); grading against *sounding* notes, so a held
half-note in one hand while the other plays eighths is handled; bar-scoped accidental
persistence; cross-clef notes (each hand is pinned to its own stave); and the image → `.song`
transcription loop.

`riverpod_lint` is **not installed**: it needs `custom_lint`, pinned to `analyzer ^8`, while
`riverpod_generator` 4.x needs `analyzer ^9`+. Re-check when bumping either.
