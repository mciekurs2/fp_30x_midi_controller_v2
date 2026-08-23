// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The seams the app is built on. Every one is overridable in a test, which is
/// what lets rounds be played, timed and scored without hardware or a store.

@ProviderFor(clock)
final clockProvider = ClockProvider._();

/// The seams the app is built on. Every one is overridable in a test, which is
/// what lets rounds be played, timed and scored without hardware or a store.

final class ClockProvider extends $FunctionalProvider<Clock, Clock, Clock>
    with $Provider<Clock> {
  /// The seams the app is built on. Every one is overridable in a test, which is
  /// what lets rounds be played, timed and scored without hardware or a store.
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<Clock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Clock create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Clock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Clock>(value),
    );
  }
}

String _$clockHash() => r'55214d6539f7396a3ae1aa23b06eea79fdac0ebe';

@ProviderFor(entropy)
final entropyProvider = EntropyProvider._();

final class EntropyProvider extends $FunctionalProvider<Random, Random, Random>
    with $Provider<Random> {
  EntropyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entropyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entropyHash();

  @$internal
  @override
  $ProviderElement<Random> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Random create(Ref ref) {
    return entropy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Random value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Random>(value),
    );
  }
}

String _$entropyHash() => r'4247224bae9cbdc60d6327304b787deec797817e';

@ProviderFor(preferencesService)
final preferencesServiceProvider = PreferencesServiceProvider._();

final class PreferencesServiceProvider
    extends
        $FunctionalProvider<
          PreferencesService,
          PreferencesService,
          PreferencesService
        >
    with $Provider<PreferencesService> {
  PreferencesServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferencesServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferencesServiceHash();

  @$internal
  @override
  $ProviderElement<PreferencesService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PreferencesService create(Ref ref) {
    return preferencesService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreferencesService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreferencesService>(value),
    );
  }
}

String _$preferencesServiceHash() =>
    r'c4c393431419b82cd1f7f90c305a857614dce56e';

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          SettingsRepository,
          SettingsRepository,
          SettingsRepository
        >
    with $Provider<SettingsRepository> {
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'e00bdae558ccdbc6e0a0ff5ef23e77dbf23f80f6';

@ProviderFor(highScoreRepository)
final highScoreRepositoryProvider = HighScoreRepositoryProvider._();

final class HighScoreRepositoryProvider
    extends
        $FunctionalProvider<
          HighScoreRepository,
          HighScoreRepository,
          HighScoreRepository
        >
    with $Provider<HighScoreRepository> {
  HighScoreRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'highScoreRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$highScoreRepositoryHash();

  @$internal
  @override
  $ProviderElement<HighScoreRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HighScoreRepository create(Ref ref) {
    return highScoreRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HighScoreRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HighScoreRepository>(value),
    );
  }
}

String _$highScoreRepositoryHash() =>
    r'caeac8692c0ff1ec79256077ae2e0ef16f33138b';

@ProviderFor(songAssetService)
final songAssetServiceProvider = SongAssetServiceProvider._();

final class SongAssetServiceProvider
    extends
        $FunctionalProvider<
          SongAssetService,
          SongAssetService,
          SongAssetService
        >
    with $Provider<SongAssetService> {
  SongAssetServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'songAssetServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$songAssetServiceHash();

  @$internal
  @override
  $ProviderElement<SongAssetService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SongAssetService create(Ref ref) {
    return songAssetService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SongAssetService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SongAssetService>(value),
    );
  }
}

String _$songAssetServiceHash() => r'23926287247618205c9f4b2c0cace5287b69b034';

@ProviderFor(songRepository)
final songRepositoryProvider = SongRepositoryProvider._();

final class SongRepositoryProvider
    extends $FunctionalProvider<SongRepository, SongRepository, SongRepository>
    with $Provider<SongRepository> {
  SongRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'songRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$songRepositoryHash();

  @$internal
  @override
  $ProviderElement<SongRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SongRepository create(Ref ref) {
    return songRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SongRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SongRepository>(value),
    );
  }
}

String _$songRepositoryHash() => r'5b4f4ca631d43d8054f8adba342bac927023ae70';

@ProviderFor(midiDeviceService)
final midiDeviceServiceProvider = MidiDeviceServiceProvider._();

final class MidiDeviceServiceProvider
    extends
        $FunctionalProvider<
          MidiDeviceService,
          MidiDeviceService,
          MidiDeviceService
        >
    with $Provider<MidiDeviceService> {
  MidiDeviceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'midiDeviceServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$midiDeviceServiceHash();

  @$internal
  @override
  $ProviderElement<MidiDeviceService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MidiDeviceService create(Ref ref) {
    return midiDeviceService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MidiDeviceService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MidiDeviceService>(value),
    );
  }
}

String _$midiDeviceServiceHash() => r'f5632eccffdce3b111a6c5390eb3f66b427a068f';
