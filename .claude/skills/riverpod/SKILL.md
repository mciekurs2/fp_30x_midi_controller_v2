---
name: riverpod
description: Usage guidelines and best practices for Riverpod 3 with code generation. Load before writing or changing any provider, notifier, or `ref.*` call, when deciding between watch/read/listen, when a provider resets unexpectedly or leaks state, or when testing anything that touches a provider.
---

# Riverpod 3 (with code generation)

Distilled from the official docs: [getting started](https://riverpod.dev/docs/introduction/getting_started),
[what's new in 3.0](https://riverpod.dev/docs/whats_new), [DO/DON'T](https://riverpod.dev/docs/root/do_dont),
[providers](https://riverpod.dev/docs/concepts2/providers), [refs](https://riverpod.dev/docs/concepts2/refs),
[testing](https://riverpod.dev/docs/how_to/testing).

## This project's setup

`hooks_riverpod` + `riverpod_annotation` (dependencies) and `riverpod_generator` + `build_runner`
(dev). Widgets are `ConsumerWidget` / `HookConsumerWidget`. `main()` wraps the app in `ProviderScope`.

**After adding or changing any annotated provider, regenerate or the app will not compile:**

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch      # during development
```

`riverpod_lint` is **not** installed: it needs `custom_lint`, which is pinned to `analyzer ^8`
while `riverpod_generator` 4.x requires `analyzer ^9`+. The rules below are therefore enforced by
review, not by the analyzer. Re-check whether they can coexist when bumping either package.

## Declaring providers

Annotate a function for read-only state, a class for state something can change:

```dart
// Read-only — recomputed when what it watches changes.
@riverpod
String songTitle(Ref ref) => ref.watch(currentSongProvider).title;

// Modifiable — the state lives in `state`, methods mutate it.
@Riverpod(keepAlive: true)
class GameController extends _$GameController {
  @override
  GameState build() => const GameState();   // initial state only, no side effects

  void start() => state = state.copyWith(phase: GamePhase.playing);
}
```

The generated provider takes its name from the declaration plus a `Provider` suffix
(`songTitle` → `songTitleProvider`, `GameController` → `gameControllerProvider`).

Async variants come from the return type — `Future<T>` generates an `AsyncNotifierProvider`,
`Stream<T>` a `StreamNotifierProvider`. Read them with `ref.watch(p)` for an `AsyncValue`, or
`await ref.read(p.future)` for the settled value.

Arguments generate a family: extra parameters on the function, or on the `build` method.

## `keepAlive` — the rule this project cares about most

Generated providers **auto-dispose by default**: the moment nothing watches one, its state is
thrown away and the next read rebuilds it from scratch.

**Any provider holding session state that is read imperatively via `.notifier` must be
`@Riverpod(keepAlive: true)`.** Settings, high scores, the MIDI connection, the note source and
the game controller all qualify — they are watched only while some widget or sheet happens to be
open, so under the default they silently reset to defaults when it closes. This was a real bug in
v1 of this app.

Use plain `@riverpod` only for genuinely derived or ephemeral state that is cheap to rebuild.

## `ref.watch` / `ref.read` / `ref.listen`

- **`watch` is the default.** Subscribes and rebuilds on change. Use it in `build` methods
  (widget and notifier alike).
- **`read` only inside event handlers** — `onPressed`, a stream callback, a timer tick. Never
  reach for `read` in a `build` method to "avoid rebuilds": that is how the UI drifts out of sync
  with the state.
- **`listen` for side effects** on change — navigation, a snackbar, starting a subscription. Safe
  to call directly in `build`.

Narrow what a widget depends on with `.select`, or it rebuilds on every unrelated field change:

```dart
final isRunning = ref.watch(gameControllerProvider.select((g) => g.phase.isRunning));
```

`ref.invalidate(p)` discards state and re-evaluates; `ref.refresh(p)` does that and returns the
new value. `ref.onDispose(cb)` registers teardown — cancel timers and stream subscriptions there;
Riverpod removes the callbacks itself, there is nothing to unregister.

## Rules

- **Providers are top-level `final` variables only.** Never build one inside a class, a method, or
  a condition — that leaks memory and breaks static analysis. Codegen enforces this by construction.
- **Providers initialise themselves.** Never have a widget call an `init()` on one from
  `initState`. Put the work in `build`, or in the event handler that genuinely triggers it.
- **No side effects during initialisation.** `build` is a read, not a write. Do not submit forms,
  post requests, or persist anything from it — the work may be skipped when a cached value exists.
- **No logic in a notifier's constructor.** It belongs in `build`.
- **Providers are for shared business state, not ephemeral UI state.** Selection, form fields,
  animation controllers and scroll positions belong to the widget — use `flutter_hooks` (already a
  dependency) or a `State`.
- **Pass providers as top-level references, not constructor parameters or fields**, or static
  analysis cannot follow them.

## Riverpod 3 specifics

- **One `Ref`.** No `FutureProviderRef`/`StreamProviderRef`/generic `Ref<T>` any more.
- **`ref.mounted`** — after an `await` inside a notifier, check it before touching `state`:
  `if (!ref.mounted) return;`.
- **`==` filters notifications** for every provider now. Immutable state classes want a real
  `==`/`hashCode` (or they will notify on every rebuild); mutable ones will *not* notify.
- **Failed providers auto-retry** with exponential backoff (200 ms doubling to 6.4 s). Configure
  per-provider with `retry:`, or globally on the scope. Do not hand-roll a retry loop.
- **Errors are wrapped** in `ProviderException`, with the original as its cause.
- **`AsyncValue` is sealed** — `switch` over it exhaustively. `valueOrNull` is now just `value`.
- **Listeners pause** when their widget is not visible (via `TickerMode`), and pausing cascades to
  dependencies. A provider driving something that must keep running regardless needs to own its
  own subscription rather than rely on a listener.
- **Legacy providers moved** to `package:riverpod/legacy.dart`: `StateProvider`,
  `StateNotifierProvider`, `ChangeNotifierProvider`. Do not introduce them.

## Testing

```dart
test('scores a correct note', () {
  final container = ProviderContainer.test(     // auto-disposed at test end
    overrides: [
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
    ],
  );

  container.read(gameControllerProvider.notifier).start();
  expect(container.read(gameControllerProvider).phase, GamePhase.playing);
});
```

- `ProviderContainer.test()`, never a bare `ProviderContainer` — the bare one is not disposed.
- Override with `overrideWith((ref) => ...)`, `overrideWithValue(v)`, or — to replace only a
  notifier's `build` — `overrideWithBuild`.
- If a provider under test auto-disposes, hold it open with
  `final sub = container.listen(p, (_, _) {});` and read through `sub.read()`.
- Async: `await expectLater(container.read(p.future), completion(expected));`.
- Widget tests: wrap in `ProviderScope(overrides: [...])` and reach the container with
  `tester.container()`.
- **Do not mock notifiers.** Mock the repository or service behind them. If a notifier mock is
  unavoidable it must `extend` the notifier base class, not merely `implement` it.
