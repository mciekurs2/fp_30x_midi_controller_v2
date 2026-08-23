// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_library.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The bundled charts, for the song picker. A chart that fails to parse is left
/// out rather than taking the list down with it.

@ProviderFor(songLibrary)
final songLibraryProvider = SongLibraryProvider._();

/// The bundled charts, for the song picker. A chart that fails to parse is left
/// out rather than taking the list down with it.

final class SongLibraryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SongInfo>>,
          List<SongInfo>,
          FutureOr<List<SongInfo>>
        >
    with $FutureModifier<List<SongInfo>>, $FutureProvider<List<SongInfo>> {
  /// The bundled charts, for the song picker. A chart that fails to parse is left
  /// out rather than taking the list down with it.
  SongLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'songLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$songLibraryHash();

  @$internal
  @override
  $FutureProviderElement<List<SongInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SongInfo>> create(Ref ref) {
    return songLibrary(ref);
  }
}

String _$songLibraryHash() => r'58733ead68d74af2858f3955ea9d7fb62b8bace5';
