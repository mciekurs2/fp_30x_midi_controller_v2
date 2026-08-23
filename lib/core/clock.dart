import 'dart:async';

/// The passage of time, behind an interface so a round's countdown can be
/// driven deterministically in tests instead of by the wall clock.
abstract interface class Clock {
  DateTime now();

  Timer periodic(Duration interval, void Function(Timer timer) callback);
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Timer periodic(Duration interval, void Function(Timer timer) callback) =>
      Timer.periodic(interval, callback);
}
