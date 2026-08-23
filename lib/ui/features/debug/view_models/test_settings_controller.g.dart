// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Knobs for the debug controls, and the note picking they drive.

@ProviderFor(TestSettingsController)
final testSettingsControllerProvider = TestSettingsControllerProvider._();

/// Knobs for the debug controls, and the note picking they drive.
final class TestSettingsControllerProvider
    extends $NotifierProvider<TestSettingsController, TestSettings> {
  /// Knobs for the debug controls, and the note picking they drive.
  TestSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'testSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$testSettingsControllerHash();

  @$internal
  @override
  TestSettingsController create() => TestSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TestSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TestSettings>(value),
    );
  }
}

String _$testSettingsControllerHash() =>
    r'a0f562f94bb3bdf81a053281d31d6429060c1705';

/// Knobs for the debug controls, and the note picking they drive.

abstract class _$TestSettingsController extends $Notifier<TestSettings> {
  TestSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TestSettings, TestSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TestSettings, TestSettings>,
              TestSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
