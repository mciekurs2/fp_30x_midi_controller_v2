// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs a round: deals an [Exercise], feeds it the note stream, keeps the clock,
/// and records the score when it ends.
///
/// It knows nothing about any particular mode — dealing and grading both go
/// through [Exercise], so this file does not change when one is added.

@ProviderFor(GameController)
final gameControllerProvider = GameControllerProvider._();

/// Runs a round: deals an [Exercise], feeds it the note stream, keeps the clock,
/// and records the score when it ends.
///
/// It knows nothing about any particular mode — dealing and grading both go
/// through [Exercise], so this file does not change when one is added.
final class GameControllerProvider
    extends $NotifierProvider<GameController, GameState> {
  /// Runs a round: deals an [Exercise], feeds it the note stream, keeps the clock,
  /// and records the score when it ends.
  ///
  /// It knows nothing about any particular mode — dealing and grading both go
  /// through [Exercise], so this file does not change when one is added.
  GameControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameControllerHash();

  @$internal
  @override
  GameController create() => GameController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GameState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GameState>(value),
    );
  }
}

String _$gameControllerHash() => r'27abf036855340fa96639b004897b7d9ea24d5d3';

/// Runs a round: deals an [Exercise], feeds it the note stream, keeps the clock,
/// and records the score when it ends.
///
/// It knows nothing about any particular mode — dealing and grading both go
/// through [Exercise], so this file does not change when one is added.

abstract class _$GameController extends $Notifier<GameState> {
  GameState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GameState, GameState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GameState, GameState>,
              GameState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
