// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The last-used settings, restored on launch and saved on every change.
///
/// Kept alive: it is read imperatively from sheets that only exist while they
/// are open, so an auto-disposing provider would drop back to the defaults the
/// moment one closed.

@ProviderFor(GameSettingsController)
final gameSettingsControllerProvider = GameSettingsControllerProvider._();

/// The last-used settings, restored on launch and saved on every change.
///
/// Kept alive: it is read imperatively from sheets that only exist while they
/// are open, so an auto-disposing provider would drop back to the defaults the
/// moment one closed.
final class GameSettingsControllerProvider
    extends $NotifierProvider<GameSettingsController, GameSettings> {
  /// The last-used settings, restored on launch and saved on every change.
  ///
  /// Kept alive: it is read imperatively from sheets that only exist while they
  /// are open, so an auto-disposing provider would drop back to the defaults the
  /// moment one closed.
  GameSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameSettingsControllerHash();

  @$internal
  @override
  GameSettingsController create() => GameSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GameSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GameSettings>(value),
    );
  }
}

String _$gameSettingsControllerHash() =>
    r'dd5e113a9d1d60c8cd34878ed3c527c18dc95150';

/// The last-used settings, restored on launch and saved on every change.
///
/// Kept alive: it is read imperatively from sheets that only exist while they
/// are open, so an auto-disposing provider would drop back to the defaults the
/// moment one closed.

abstract class _$GameSettingsController extends $Notifier<GameSettings> {
  GameSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GameSettings, GameSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GameSettings, GameSettings>,
              GameSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
