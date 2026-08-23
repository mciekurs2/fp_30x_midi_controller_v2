import 'dart:async';

import 'package:fp_30x_midi_controller_v2/core/clock.dart';
import 'package:fp_30x_midi_controller_v2/data/services/midi_device_service.dart';
import 'package:fp_30x_midi_controller_v2/data/services/preferences_service.dart';
import 'package:fp_30x_midi_controller_v2/data/services/song_asset_service.dart';
import 'package:fp_30x_midi_controller_v2/domain/models/note_event.dart';

/// An in-memory store, so persistence can be exercised without the platform
/// plugin. [raw] is writable, which is how a corrupt store is simulated.
class FakePreferencesService implements PreferencesService {
  FakePreferencesService([Map<String, Object>? initial])
    : raw = {...?initial};

  final Map<String, Object> raw;

  @override
  Future<String?> getString(String key) async => raw[key] as String?;

  @override
  Future<int?> getInt(String key) async => raw[key] as int?;

  @override
  Future<bool?> getBool(String key) async => raw[key] as bool?;

  @override
  Future<List<int>?> getIntList(String key) async {
    final stored = raw[key] as List<String>?;
    if (stored == null) return null;
    return [for (final entry in stored) ?int.tryParse(entry)];
  }

  @override
  Future<Set<String>> keysWithPrefix(String prefix) async =>
      raw.keys.where((key) => key.startsWith(prefix)).toSet();

  @override
  Future<void> setString(String key, String value) async => raw[key] = value;

  @override
  Future<void> setInt(String key, int value) async => raw[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => raw[key] = value;

  @override
  Future<void> setIntList(String key, List<int> values) async =>
      raw[key] = [for (final v in values) '$v'];
}

/// Charts held in memory rather than in the asset bundle.
class FakeSongAssetService implements SongAssetService {
  FakeSongAssetService(this.songs);

  final Map<String, String> songs;

  @override
  Future<List<String>> listSongs() async => songs.keys.toList()..sort();

  @override
  Future<String> read(String asset) async => songs[asset]!;
}

/// A piano that is never there, with a hand-driven note stream.
class FakeMidiDeviceService implements MidiDeviceService {
  final notesController = StreamController<NoteEvent>.broadcast();
  final _statuses = StreamController<MidiConnectionStatus>.broadcast();
  var _status = MidiConnectionStatus.offline;

  @override
  MidiConnectionStatus get status => _status;

  @override
  Stream<MidiConnectionStatus> get statusChanges => _statuses.stream;

  @override
  Stream<NoteEvent> get notes => notesController.stream;

  @override
  Future<void> connect() async => _set(MidiConnectionStatus.connected);

  @override
  Future<void> disconnect() async => _set(MidiConnectionStatus.offline);

  @override
  Future<void> dispose() async {
    await notesController.close();
    await _statuses.close();
  }

  void _set(MidiConnectionStatus status) {
    _status = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }
}

/// A clock that only moves when told, so a countdown can be run instantly.
class FakeClock implements Clock {
  FakeClock([DateTime? start])
    : _now = start ?? DateTime.utc(2026, 1, 1);

  DateTime _now;
  final _timers = <_FakeTimer>[];

  @override
  DateTime now() => _now;

  @override
  Timer periodic(Duration interval, void Function(Timer timer) callback) {
    final timer = _FakeTimer(interval, callback, _timers.remove);
    _timers.add(timer);
    return timer;
  }

  /// Advances time, firing every periodic tick that falls inside the jump.
  void advance(Duration by) {
    final target = _now.add(by);
    while (_now.isBefore(target)) {
      final step = _timers.isEmpty
          ? by
          : _timers.map((t) => t.interval).reduce((a, b) => a < b ? a : b);
      _now = _now.add(step);
      if (_now.isAfter(target)) _now = target;
      for (final timer in [..._timers]) {
        if (timer.isActive) timer.callback(timer);
      }
    }
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.interval, this.callback, this._remove);

  final Duration interval;
  final void Function(Timer timer) callback;
  final void Function(_FakeTimer timer) _remove;
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _active = false;
    _remove(this);
  }
}
