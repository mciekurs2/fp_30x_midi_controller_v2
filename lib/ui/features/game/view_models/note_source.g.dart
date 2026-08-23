// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single source of note events. Real MIDI and the debug controls' [play]
/// both funnel through one path, so everything downstream — grading, the staff,
/// the readout — sees one stream and one set of held keys. Being able to drive
/// the whole game without a piano falls out of that.
///
/// State is the keys currently down, mapped to the velocity they were struck at.

@ProviderFor(NoteSource)
final noteSourceProvider = NoteSourceProvider._();

/// The single source of note events. Real MIDI and the debug controls' [play]
/// both funnel through one path, so everything downstream — grading, the staff,
/// the readout — sees one stream and one set of held keys. Being able to drive
/// the whole game without a piano falls out of that.
///
/// State is the keys currently down, mapped to the velocity they were struck at.
final class NoteSourceProvider
    extends $NotifierProvider<NoteSource, Map<int, int>> {
  /// The single source of note events. Real MIDI and the debug controls' [play]
  /// both funnel through one path, so everything downstream — grading, the staff,
  /// the readout — sees one stream and one set of held keys. Being able to drive
  /// the whole game without a piano falls out of that.
  ///
  /// State is the keys currently down, mapped to the velocity they were struck at.
  NoteSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteSourceHash();

  @$internal
  @override
  NoteSource create() => NoteSource();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, int>>(value),
    );
  }
}

String _$noteSourceHash() => r'2e1a517dee39cc609cf40606451475ee06ae6bab';

/// The single source of note events. Real MIDI and the debug controls' [play]
/// both funnel through one path, so everything downstream — grading, the staff,
/// the readout — sees one stream and one set of held keys. Being able to drive
/// the whole game without a piano falls out of that.
///
/// State is the keys currently down, mapped to the velocity they were struck at.

abstract class _$NoteSource extends $Notifier<Map<int, int>> {
  Map<int, int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<int, int>, Map<int, int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<int, int>, Map<int, int>>,
              Map<int, int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
