import 'package:flutter/services.dart';

/// Reads the bundled `.song` charts. Behind an interface so the library and the
/// parser can be tested without an asset bundle.
abstract interface class SongAssetService {
  /// Asset paths of every bundled chart, sorted.
  Future<List<String>> listSongs();

  Future<String> read(String asset);
}

class BundledSongAssetService implements SongAssetService {
  const BundledSongAssetService();

  static const _directory = 'assets/songs/';
  static const _extension = '.song';

  @override
  Future<List<String>> listSongs() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest
        .listAssets()
        .where((a) => a.startsWith(_directory) && a.endsWith(_extension))
        .toList()
      ..sort();
  }

  @override
  Future<String> read(String asset) => rootBundle.loadString(asset);
}
