import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../domain/models/game_settings.dart';
import '../../../../domain/models/note_event.dart';
import '../../../core/widgets/sheet.dart';
import '../../game/view_models/game_controller.dart';
import '../../game/view_models/note_source.dart';
import '../view_models/test_settings_controller.dart';

/// A keyboard stand-in: a "Play note" button that simulates a keypress, plus a
/// sheet for what it plays. Debug builds only.
///
/// The press goes down the same path as real MIDI, so it exercises every mode's
/// full grading — which is what makes the game playable without the piano.
class TestControls extends ConsumerStatefulWidget {
  const TestControls({super.key});

  @override
  ConsumerState<TestControls> createState() => _TestControlsState();
}

class _TestControlsState extends ConsumerState<TestControls> {
  /// What this view is holding down; never a real key.
  List<int> _held = const [];

  @override
  void dispose() {
    // Never leave a simulated key stuck down if the view goes away mid-press.
    _release();
    super.dispose();
  }

  void _release() {
    if (_held.isEmpty) return;
    final notes = ref.read(noteSourceProvider.notifier);
    for (final note in _held) {
      notes.play(NoteReleased(note));
    }
    _held = const [];
  }

  /// Held for exactly as long as the button is, so note length is the press
  /// length. Replaces what is down rather than stacking notes into a chord.
  void _press() {
    _release();
    // What the round is asking for, so Target/50-50 can aim at it.
    final targets = ref.read(gameControllerProvider.notifier).currentTargets();
    final notes = ref
        .read(testSettingsControllerProvider.notifier)
        .nextNotes(targets);
    if (notes.isEmpty) return;

    final source = ref.read(noteSourceProvider.notifier);
    for (final note in notes) {
      source.play(NotePressed(note, 80));
    }
    _held = notes;
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: .min,
    spacing: sheetSpacing,
    children: [
      // A Listener rather than the button's onPressed, so the note is down for
      // the whole press and released the moment the finger lifts.
      Listener(
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: FilledButton.tonalIcon(
          onPressed: () {},
          icon: const Icon(Icons.piano),
          label: const Text('Play note'),
        ),
      ),
      IconButton.filledTonal(
        onPressed: () => showAppSheet(context, const _TestSettingsSheet()),
        icon: const Icon(Icons.tune),
        tooltip: 'Test settings',
      ),
    ],
  );
}

class _TestSettingsSheet extends ConsumerWidget {
  const _TestSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(testSettingsControllerProvider);
    final notifier = ref.read(testSettingsControllerProvider.notifier);

    return SheetBody(
      children: [
        const SheetHeader(title: 'Note source'),
        ChipRow<TestNoteSource>(
          items: TestNoteSource.values,
          label: (source) => source.title,
          isSelected: (source) => settings.noteSource == source,
          onSelected: (source, _) => notifier.setSource(source),
        ),
        const SheetHeader(title: 'Octaves'),
        ChipRow<int>(
          items: GameSettings.octaveBounds,
          multiple: true,
          label: (octave) => '$octave',
          isSelected: settings.octaves.contains,
          onSelected: (octave, selected) {
            final next = {...settings.octaves};
            if (selected) {
              next.add(octave);
            } else {
              next.remove(octave);
            }
            notifier.setOctaves(next);
          },
        ),
      ],
    );
  }
}
