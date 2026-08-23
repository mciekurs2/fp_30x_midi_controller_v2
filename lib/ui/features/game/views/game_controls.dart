import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../domain/models/game_mode.dart';
import '../../../../domain/models/game_settings.dart';
import '../../../../domain/models/music_key.dart';
import '../../../../domain/models/song.dart';
import '../../../core/widgets/sheet.dart';
import '../view_models/game_controller.dart';
import '../view_models/game_settings_controller.dart';
import '../view_models/song_library.dart';

/// Bottom-left chrome: the mode picker and the settings sheet, both locked
/// while a round is running.
class GameControls extends ConsumerWidget {
  const GameControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      gameSettingsControllerProvider.select((s) => s.mode),
    );
    final isRunning = ref.watch(
      gameControllerProvider.select((g) => g.isRunning),
    );

    return Row(
      mainAxisSize: .min,
      spacing: sheetSpacing,
      children: [
        // Flexible with an ellipsis: at the app's 1.5x text scale the longest
        // mode name runs past the edge of a 360 dp phone otherwise.
        Flexible(
          child: FilledButton.tonalIcon(
            onPressed: isRunning
                ? null
                : () => showAppSheet(context, const _ModeSheet()),
            icon: const Icon(Icons.sports_esports),
            label: Text(mode.title, maxLines: 1, overflow: .ellipsis),
          ),
        ),
        IconButton.filledTonal(
          onPressed: isRunning
              ? null
              : () => showAppSheet(context, const _SettingsSheet()),
          icon: const Icon(Icons.tune),
          tooltip: 'Game settings',
        ),
      ],
    );
  }
}

/// The icon each mode is listed under. Kept here rather than on [GameMode], so
/// the domain carries no Flutter import.
IconData _iconFor(GameMode mode) => switch (mode) {
  GameMode.singleNote => Icons.back_hand,
  GameMode.chords => Icons.piano,
  GameMode.keyChords => Icons.tag,
  GameMode.song => Icons.library_music,
};

class _ModeSheet extends ConsumerWidget {
  const _ModeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      gameSettingsControllerProvider.select((s) => s.mode),
    );
    final settings = ref.read(gameSettingsControllerProvider.notifier);

    return SheetBody(
      children: [
        Text('Game mode', style: Theme.of(context).textTheme.titleMedium),
        for (final option in GameMode.values)
          ListTile(
            contentPadding: .zero,
            leading: Icon(_iconFor(option)),
            title: Text(option.title),
            trailing: option == mode ? const Icon(Icons.check) : null,
            onTap: () {
              settings.setMode(option);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// The settings sheet, built from the knobs the mode declares rather than from
/// a branch per mode. A new mode picks its controls by listing them in
/// [GameMode.knobs]; nothing here changes.
class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gameSettingsControllerProvider);
    final knobs = settings.mode.knobs;

    return SheetBody(
      children: [
        if (knobs.contains(SettingKnob.duration)) const _DurationKnob(),
        if (knobs.contains(SettingKnob.chordKey)) const _KeyKnob(),
        if (knobs.contains(SettingKnob.octaves)) const _OctavesKnob(),
        if (knobs.contains(SettingKnob.song)) const _SongKnob(),
        if (knobs.contains(SettingKnob.hands)) const _HandsKnob(),
      ],
    );
  }
}

String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class _DurationKnob extends ConsumerWidget {
  const _DurationKnob();

  static const _divisions =
      (GameSettings.maxDuration - GameSettings.minDuration) ~/
      GameSettings.durationStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gameSettingsControllerProvider);
    final notifier = ref.read(gameSettingsControllerProvider.notifier);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: sheetSpacing,
      children: [
        SheetHeader(
          title: 'Time limit',
          value: settings.untimed ? '—' : _clock(settings.durationSeconds),
        ),
        // Dimmed by hand so the whole block reads as one switched-off unit.
        Opacity(
          opacity: settings.untimed ? 0.4 : 1,
          child: Slider(
            value: settings.durationSeconds.toDouble(),
            min: GameSettings.minDuration.toDouble(),
            max: GameSettings.maxDuration.toDouble(),
            divisions: _divisions,
            label: _clock(settings.durationSeconds),
            padding: .zero,
            onChanged: settings.untimed
                ? null
                : (value) => notifier.setDuration(value.round()),
          ),
        ),
        SwitchListTile(
          contentPadding: .zero,
          title: Text(
            'No time limit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          value: settings.untimed,
          onChanged: notifier.setUntimed,
        ),
      ],
    );
  }
}

class _OctavesKnob extends ConsumerWidget {
  const _OctavesKnob();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final octaves = ref.watch(
      gameSettingsControllerProvider.select((s) => s.octaves),
    );
    final notifier = ref.read(gameSettingsControllerProvider.notifier);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: sheetSpacing,
      children: [
        const SheetHeader(title: 'Octaves'),
        ChipRow<int>(
          items: GameSettings.octaveBounds,
          multiple: true,
          label: (octave) => '$octave',
          isSelected: octaves.contains,
          onSelected: (octave, selected) {
            final next = {...octaves};
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

/// Chords-in-key: the one key every chord is drawn from. A tonality pair over
/// the twelve tonics, each chip labelled by the key it would make — so pitch
/// class 6 reads Gb under Major and F# under Minor with no table of its own.
class _KeyKnob extends ConsumerWidget {
  const _KeyKnob();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(
      gameSettingsControllerProvider.select((s) => s.chordKey),
    );
    final notifier = ref.read(gameSettingsControllerProvider.notifier);

    MusicKey keyOn(int pitchClass) => chosen.tonality == Tonality.major
        ? MusicKey.major(pitchClass)
        : MusicKey.minor(pitchClass);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: sheetSpacing,
      children: [
        SheetHeader(title: 'Key', value: chosen.name),
        ChipRow<Tonality>(
          items: Tonality.values,
          label: (tonality) => tonality.title,
          isSelected: (tonality) => chosen.tonality == tonality,
          // Same tonic, other tonality: C major becomes C minor, not whatever
          // key happens to share the signature.
          onSelected: (tonality, _) => notifier.setChordKey(
            tonality == Tonality.major
                ? MusicKey.major(chosen.tonicPitchClass)
                : MusicKey.minor(chosen.tonicPitchClass),
          ),
        ),
        // Twelve chips in one row are unreadably narrow on a phone.
        for (final row in const [
          [0, 1, 2, 3, 4, 5],
          [6, 7, 8, 9, 10, 11],
        ])
          ChipRow<int>(
            items: row,
            label: (pitchClass) => keyOn(pitchClass).tonicName,
            isSelected: (pitchClass) => keyOn(pitchClass) == chosen,
            onSelected: (pitchClass, _) =>
                notifier.setChordKey(keyOn(pitchClass)),
          ),
      ],
    );
  }
}

class _SongKnob extends ConsumerWidget {
  const _SongKnob();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(
      gameSettingsControllerProvider.select((s) => s.songAsset),
    );
    final notifier = ref.read(gameSettingsControllerProvider.notifier);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const SheetHeader(title: 'Song'),
        ref
            .watch(songLibraryProvider)
            .when(
              loading: () => const Padding(
                padding: .all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Text('Could not load songs.'),
              data: (songs) => Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  if (songs.isEmpty) const Text('No songs bundled.'),
                  for (final song in songs)
                    ListTile(
                      contentPadding: .zero,
                      title: Text(song.title),
                      trailing: song.asset == chosen
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => notifier.setSong(song.asset),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _HandsKnob extends ConsumerWidget {
  const _HandsKnob();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hands = ref.watch(
      gameSettingsControllerProvider.select((s) => s.hands),
    );
    final notifier = ref.read(gameSettingsControllerProvider.notifier);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: sheetSpacing,
      children: [
        const SheetHeader(title: 'Hands'),
        ChipRow<PlayHands>(
          items: PlayHands.values,
          label: (hand) => hand.title,
          isSelected: (hand) => hands == hand,
          onSelected: (hand, _) => notifier.setHands(hand),
        ),
      ],
    );
  }
}
