import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:flutter_midi_command_ble/flutter_midi_command_ble.dart';

import '../../domain/models/note_event.dart';

enum MidiConnectionStatus { offline, connecting, connected }

/// The piano as a source of note events, behind an interface so the game can be
/// driven by a fake in tests instead of by hardware.
abstract interface class MidiDeviceService {
  MidiConnectionStatus get status;

  Stream<MidiConnectionStatus> get statusChanges;

  Stream<NoteEvent> get notes;

  /// Starts watching for the piano and connects as soon as it appears.
  Future<void> connect();

  /// Disconnects and stops reconnecting until [connect] is called again.
  Future<void> disconnect();

  Future<void> dispose();
}

/// Bluetooth MIDI, over `flutter_midi_command`.
///
/// Keeps a standing watch for the FP-30X so it is picked up whenever it powers
/// on, and reconnects after a drop — unless the user disconnected by hand.
class BleMidiDeviceService implements MidiDeviceService {
  BleMidiDeviceService({MidiCommand? command})
    : _midi = command ?? MidiCommand() {
    _midi.configureBleTransport(UniversalBleMidiTransport());
  }

  static const _deviceNameMatch = 'FP-30X';
  static const _connectTimeout = Duration(seconds: 10);
  static const _bluetoothInitTimeout = Duration(seconds: 5);
  static const _logName = 'fp30x.midi';

  final MidiCommand _midi;
  final _notes = StreamController<NoteEvent>.broadcast();
  final _statuses = StreamController<MidiConnectionStatus>.broadcast();

  StreamSubscription<MidiSetupChange>? _setupWatch;
  StreamSubscription<MidiConnectionState>? _deviceWatch;
  StreamSubscription<MidiDataReceivedEvent>? _dataWatch;

  /// Invalidates a connection attempt superseded by a newer one.
  int _attempt = 0;
  MidiDevice? _device;

  /// User intent: (re)connect while true; a manual disconnect clears it.
  bool _autoConnect = false;

  /// Guards against overlapping auto-connect attempts.
  bool _connecting = false;

  var _status = MidiConnectionStatus.offline;

  @override
  MidiConnectionStatus get status => _status;

  @override
  Stream<MidiConnectionStatus> get statusChanges => _statuses.stream;

  @override
  Stream<NoteEvent> get notes => _notes.stream;

  @override
  Future<void> connect() async {
    _autoConnect = true;
    await _startWatching();
  }

  @override
  Future<void> disconnect() async {
    _autoConnect = false;
    _attempt++; // invalidate any in-flight attempt
    _midi.stopScanningForBluetoothDevices();
    await _deviceWatch?.cancel();
    _deviceWatch = null;
    await _dataWatch?.cancel();
    _dataWatch = null;

    if (_device case final device?) {
      _log('disconnecting from ${device.name}');
      _midi.disconnectDevice(device);
      _device = null;
    }
    _setStatus(MidiConnectionStatus.offline);
  }

  @override
  Future<void> dispose() async {
    _autoConnect = false;
    await _setupWatch?.cancel();
    await _deviceWatch?.cancel();
    await _dataWatch?.cancel();
    _midi.stopScanningForBluetoothDevices();
    if (_device case final device?) _midi.disconnectDevice(device);
    await _notes.close();
    await _statuses.close();
  }

  /// Brings up Bluetooth and scans for the piano. Safe to call repeatedly.
  Future<void> _startWatching() async {
    await _midi.startBluetooth();
    await _midi
        .waitUntilBluetoothIsInitialized()
        .timeout(
          _bluetoothInitTimeout,
          onTimeout: () => _log('bluetooth init timed out'),
        );

    if (_midi.bluetoothState != BluetoothState.poweredOn) {
      _log('bluetooth not powered on: ${_midi.bluetoothState}');
      return;
    }

    _setupWatch ??= _midi.onMidiSetupChanged?.listen(
      (_) => unawaited(_maybeConnect()),
    );

    await _midi.startScanningForBluetoothDevices();
    await _maybeConnect(); // in case the piano is already present
  }

  Future<void> _maybeConnect() async {
    if (_connecting) return;
    if (!_autoConnect || _status != MidiConnectionStatus.offline) return;

    _connecting = true;
    try {
      final device = await _findDevice();
      if (device == null) return;
      // Intent or state may have changed while we were looking.
      if (_autoConnect && _status == MidiConnectionStatus.offline) {
        await _connectTo(device);
      }
    } finally {
      _connecting = false;
    }
  }

  Future<MidiDevice?> _findDevice() async {
    final devices = await _midi.devices ?? const <MidiDevice>[];
    for (final device in devices) {
      if (device.name.contains(_deviceNameMatch)) return device;
    }
    return null;
  }

  Future<void> _connectTo(MidiDevice device) async {
    final attempt = ++_attempt;
    _setStatus(MidiConnectionStatus.connecting);
    try {
      if (device.connected) {
        _log('${device.name} already connected, adopting');
      } else {
        await _midi
            .connectToDevice(device, awaitConnectionTimeout: null)
            .timeout(_connectTimeout);
      }
      if (attempt != _attempt) return; // superseded
      _adopt(device);
    } on TimeoutException {
      _log('timed out connecting to ${device.name}');
    } catch (error, stackTrace) {
      _log('connection failed', error: error, stackTrace: stackTrace);
    } finally {
      if (attempt == _attempt && _status != MidiConnectionStatus.connected) {
        _setStatus(MidiConnectionStatus.offline);
      }
    }
  }

  /// Adopts [device] as the live connection and watches for it dropping.
  void _adopt(MidiDevice device) {
    _log('connected to ${device.name}');
    _device = device;
    _midi.stopScanningForBluetoothDevices();

    _dataWatch?.cancel();
    _dataWatch = _midi.onMidiDataReceived?.listen(_onData);

    _deviceWatch?.cancel();
    _deviceWatch = device.onConnectionStateChanged.listen((connectionState) {
      if (connectionState != MidiConnectionState.disconnected) return;
      if (!identical(_device, device)) return;
      _log('${device.name} dropped');
      _device = null;
      _dataWatch?.cancel();
      _dataWatch = null;
      _setStatus(MidiConnectionStatus.offline);
      // Switched off or out of range — watch again so it reconnects on return.
      if (_autoConnect) unawaited(_startWatching());
    });

    _setStatus(MidiConnectionStatus.connected);
  }

  void _onData(MidiDataReceivedEvent event) {
    // The package normalizes velocity-0 note-on to note-off, so type is enough.
    switch (event.message) {
      case NoteOnMessage(:final note, :final velocity):
        _notes.add(NotePressed(note, velocity));
      case NoteOffMessage(:final note):
        _notes.add(NoteReleased(note));
    }
  }

  void _setStatus(MidiConnectionStatus status) {
    if (status == _status) return;
    _status = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(
        message,
        name: _logName,
        error: error,
        stackTrace: stackTrace,
      );
}
