import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/stadium/stadium_initial_snapshot_guard.dart';

void main() {
  test('idle realtime venue stays healthy after its first snapshot', () async {
    final source = StreamController<int>();
    final values = <int>[];
    final errors = <Object>[];
    final subscription = StadiumInitialSnapshotGuard.apply(
      source.stream,
      timeout: const Duration(milliseconds: 20),
    ).listen(values.add, onError: errors.add);

    source.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    source.add(2);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(values, [1, 2]);
    expect(errors, isEmpty);
    await subscription.cancel();
    await source.close();
  });

  test('a missing initial snapshot expires and cancels the source', () async {
    final source = StreamController<int>();
    final values = <int>[];
    final errors = <Object>[];
    final subscription = StadiumInitialSnapshotGuard.apply(
      source.stream,
      timeout: const Duration(milliseconds: 20),
    ).listen(values.add, onError: errors.add);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(values, isEmpty);
    expect(errors.single, isA<StateError>());
    expect(source.hasListener, isFalse);
    await subscription.cancel();
    await source.close();
  });
}
