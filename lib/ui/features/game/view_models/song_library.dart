import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers.dart';
import '../../../../data/repositories/song_repository.dart';

part 'song_library.g.dart';

/// The bundled charts, for the song picker. A chart that fails to parse is left
/// out rather than taking the list down with it.
@Riverpod(keepAlive: true)
Future<List<SongInfo>> songLibrary(Ref ref) =>
    ref.watch(songRepositoryProvider).library();
