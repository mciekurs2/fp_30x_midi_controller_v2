import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../data/services/midi_device_service.dart';
import '../../game/view_models/midi_connection.dart';

/// The piano's connection, and a tap to connect or disconnect.
class ConnectionBadge extends ConsumerWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, color) = switch (ref.watch(midiConnectionProvider)) {
      MidiConnectionStatus.offline => ('Offline', Colors.grey),
      MidiConnectionStatus.connecting => ('Connecting', Colors.orange),
      MidiConnectionStatus.connected => ('Connected', Colors.green),
    };

    return FilledButton.tonalIcon(
      onPressed: ref.read(midiConnectionProvider.notifier).toggle,
      icon: Icon(Icons.circle, size: 12, color: color),
      label: Text(label, maxLines: 1, overflow: .ellipsis),
    );
  }
}
