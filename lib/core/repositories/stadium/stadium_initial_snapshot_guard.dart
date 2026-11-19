import 'dart:async';

/// Expires only an initial stadium load. A quiet realtime subscription after
/// its first event is healthy and must not be reported as a refresh failure.
class StadiumInitialSnapshotGuard {
  const StadiumInitialSnapshotGuard._();

  static Stream<T> apply<T>(
    Stream<T> source, {
    required Duration timeout,
  }) {
    StreamSubscription<T>? subscription;
    Timer? initialTimer;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        initialTimer = Timer(timeout, () {
          if (controller.isClosed) return;
          controller.addError(StateError('stadium_stream_initial_timeout'));
          final pendingCancellation = subscription?.cancel();
          if (pendingCancellation != null) unawaited(pendingCancellation);
          unawaited(controller.close());
        });
        subscription = source.listen(
          (event) {
            initialTimer?.cancel();
            initialTimer = null;
            if (!controller.isClosed) controller.add(event);
          },
          onError: (Object error, StackTrace stackTrace) {
            initialTimer?.cancel();
            initialTimer = null;
            if (!controller.isClosed) controller.addError(error, stackTrace);
          },
          onDone: () {
            initialTimer?.cancel();
            unawaited(controller.close());
          },
        );
      },
      onCancel: () async {
        initialTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
