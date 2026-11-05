/// Block slot: current time. Lets tests travel in time.
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Always returns the same instant. Create a new one to move time.
final class FixedClock implements Clock {
  const FixedClock(this.instant);

  final DateTime instant;

  FixedClock advance(Duration by) => FixedClock(instant.add(by));

  @override
  DateTime now() => instant;
}
