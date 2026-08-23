// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'high_scores.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Top scores per settings bucket, cached in memory so the HUD reads them
/// synchronously and rebuilds when a new score lands.

@ProviderFor(HighScores)
final highScoresProvider = HighScoresProvider._();

/// Top scores per settings bucket, cached in memory so the HUD reads them
/// synchronously and rebuilds when a new score lands.
final class HighScoresProvider
    extends $NotifierProvider<HighScores, Map<String, List<int>>> {
  /// Top scores per settings bucket, cached in memory so the HUD reads them
  /// synchronously and rebuilds when a new score lands.
  HighScoresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'highScoresProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$highScoresHash();

  @$internal
  @override
  HighScores create() => HighScores();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, List<int>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, List<int>>>(value),
    );
  }
}

String _$highScoresHash() => r'841c2b18c976dcc665467aa9873a4a5568da0803';

/// Top scores per settings bucket, cached in memory so the HUD reads them
/// synchronously and rebuilds when a new score lands.

abstract class _$HighScores extends $Notifier<Map<String, List<int>>> {
  Map<String, List<int>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<Map<String, List<int>>, Map<String, List<int>>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, List<int>>, Map<String, List<int>>>,
              Map<String, List<int>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
