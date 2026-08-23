import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers.dart';
import '../../../../domain/models/note_event.dart';

part 'note_source.g.dart';

/// The single source of note events. Real MIDI and the debug controls' [play]
/// both funnel through one path, so everything downstream — grading, the staff,
/// the readout — sees one stream and one set of held keys. Being able to drive
/// the whole game without a piano falls out of that.
///
/// State is the keys currently down, mapped to the velocity they were struck at.
@Riverpod(keepAlive: true)
class NoteSource extends _$NoteSource {
  final _events = StreamController<NoteEvent>.broadcast();
  StreamSubscription<NoteEvent>? _device;

  Stream<NoteEvent> get events => _events.stream;

  @override
  Map<int, int> build() {
    _device = ref.watch(midiDeviceServiceProvider).notes.listen(_receive);
    ref.onDispose(() {
      _device?.cancel();
      _events.close();
    });
    return const {};
  }

  /// Injects a synthetic event down the same path as hardware.
  void play(NoteEvent event) => _receive(event);

  void _receive(NoteEvent event) {
    state = switch (event) {
      NotePressed(:final note, :final velocity) => {...state, note: velocity},
      NoteReleased(:final note) => {...state}..remove(note),
    };
    if (!_events.isClosed) _events.add(event);
  }
}
