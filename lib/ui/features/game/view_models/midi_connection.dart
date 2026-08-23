import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers.dart';
import '../../../../data/services/midi_device_service.dart';

part 'midi_connection.g.dart';

/// The piano's connection, as the status badge shows it.
///
/// The service keeps a standing watch and reconnects on its own; this only
/// mirrors its status and carries the badge's tap.
@Riverpod(keepAlive: true)
class MidiConnection extends _$MidiConnection {
  MidiDeviceService get _service => ref.read(midiDeviceServiceProvider);

  @override
  MidiConnectionStatus build() {
    final service = ref.watch(midiDeviceServiceProvider);
    final watch = service.statusChanges.listen((status) => state = status);
    ref.onDispose(watch.cancel);
    unawaited(service.connect());
    return service.status;
  }

  /// Connect when offline, else disconnect and stop reconnecting.
  Future<void> toggle() => state == MidiConnectionStatus.offline
      ? _service.connect()
      : _service.disconnect();
}
