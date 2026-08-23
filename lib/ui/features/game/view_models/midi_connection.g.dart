// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'midi_connection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The piano's connection, as the status badge shows it.
///
/// The service keeps a standing watch and reconnects on its own; this only
/// mirrors its status and carries the badge's tap.

@ProviderFor(MidiConnection)
final midiConnectionProvider = MidiConnectionProvider._();

/// The piano's connection, as the status badge shows it.
///
/// The service keeps a standing watch and reconnects on its own; this only
/// mirrors its status and carries the badge's tap.
final class MidiConnectionProvider
    extends $NotifierProvider<MidiConnection, MidiConnectionStatus> {
  /// The piano's connection, as the status badge shows it.
  ///
  /// The service keeps a standing watch and reconnects on its own; this only
  /// mirrors its status and carries the badge's tap.
  MidiConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'midiConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$midiConnectionHash();

  @$internal
  @override
  MidiConnection create() => MidiConnection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MidiConnectionStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MidiConnectionStatus>(value),
    );
  }
}

String _$midiConnectionHash() => r'3b6ff0422ecba45d16eccb3d8749f813878445f5';

/// The piano's connection, as the status badge shows it.
///
/// The service keeps a standing watch and reconnects on its own; this only
/// mirrors its status and carries the badge's tap.

abstract class _$MidiConnection extends $Notifier<MidiConnectionStatus> {
  MidiConnectionStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MidiConnectionStatus, MidiConnectionStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MidiConnectionStatus, MidiConnectionStatus>,
              MidiConnectionStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
