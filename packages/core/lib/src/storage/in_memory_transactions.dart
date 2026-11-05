import 'dart:async';

/// Transactions for an in-memory block, with the meaning the ports promise:
///
/// - a failed [transaction] restores the state taken just before it ran;
/// - calls made inside it (same zone) run at once and see its writes;
/// - calls from outside wait in a queue until it ends;
/// - a nested [transaction] is a savepoint: only its own writes are undone.
final class InMemoryTransactions<S> {
  InMemoryTransactions({required this.snapshot, required this.restore});

  /// Copies the current state (values are immutable, shallow copies suffice).
  final S Function() snapshot;

  /// Puts back a state taken by [snapshot].
  final void Function(S state) restore;

  final Object _zoneKey = Object();
  Future<void> _tail = Future<void>.value();

  bool get _inside => Zone.current[_zoneKey] == true;

  /// Runs one plain read or write, after a transaction that is running.
  Future<T> run<T>(T Function() body) =>
      _inside ? Future.sync(body) : _queued(() => Future.sync(body));

  Future<T> transaction<T>(Future<T> Function() action) {
    if (_inside) return _attempt(action);
    return _queued(
      () => runZoned(() => _attempt(action), zoneValues: {_zoneKey: true}),
    );
  }

  Future<T> _attempt<T>(Future<T> Function() action) async {
    final before = snapshot();
    try {
      return await action();
    } catch (_) {
      restore(before);
      rethrow;
    }
  }

  Future<T> _queued<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    // The queue moves on whether the call succeeded or not; the caller still
    // gets the error through [result].
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
