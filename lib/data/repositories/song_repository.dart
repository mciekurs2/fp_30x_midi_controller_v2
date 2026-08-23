import '../../domain/models/song.dart';
import '../parsing/song_parser.dart';
import '../services/song_asset_service.dart';

/// A chart in the bundled library: its asset path and display [title].
class SongInfo {
  const SongInfo({required this.asset, required this.title});

  final String asset;
  final String title;
}

/// The bundled songs, discovered from the asset manifest so dropping a new
/// `.song` file in needs no code change.
///
/// A chart that fails to parse is left out of the library rather than taking
/// the app down with it — the charts are transcribed by hand, and one typo
/// should cost that piece, not every piece.
class SongRepository {
  SongRepository(this._assets);

  final SongAssetService _assets;

  List<SongInfo>? _library;
  final _parsed = <String, Song>{};

  /// Charts that failed to parse, by asset path — surfaced so a broken file is
  /// reported rather than silently missing.
  final brokenSongs = <String, SongFormatException>{};

  Future<List<SongInfo>> library() async {
    if (_library case final cached?) return cached;
    final songs = <SongInfo>[];
    for (final asset in await _assets.listSongs()) {
      final song = await _parse(asset);
      if (song != null) songs.add(SongInfo(asset: asset, title: song.title));
    }
    return _library = songs;
  }

  /// The chosen chart, or the first that parses when nothing is chosen or the
  /// choice no longer exists — a saved asset path outlives the build that
  /// removed its file, and a round must always be able to start. `null` only
  /// when the library holds nothing readable.
  Future<Song?> load(String? preferred) async {
    final library = await this.library();
    if (library.isEmpty) return null;
    final asset = library.any((song) => song.asset == preferred)
        ? preferred!
        : library.first.asset;
    return _parse(asset);
  }

  Future<Song?> _parse(String asset) async {
    if (_parsed[asset] case final cached?) return cached;
    try {
      return _parsed[asset] = parseSong(await _assets.read(asset));
    } on SongFormatException catch (error) {
      brokenSongs[asset] = error;
      return null;
    }
  }
}
