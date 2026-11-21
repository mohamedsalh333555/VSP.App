import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';
import 'package:vsp_application/data/models.dart';

class _StrictLookupRepository extends StadiumRepository {
  final result = Completer<Stadium?>();

  @override
  Future<Stadium?> getStadiumByIdStrict(String id) => result.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed authoritative details read is a retryable error, not absence',
      () async {
    final repo = _StrictLookupRepository();
    final provider = StadiumProvider(repository: repo);
    addTearDown(provider.dispose);

    final lookup = provider.getStadiumById('pitch-A');
    repo.result.completeError(StateError('PRIVATE_BACKEND_AUTH_TOKEN'));
    await expectLater(lookup, throwsStateError);
    expect(provider.errorMessage, 'stadium_fetch_failed');
    expect(provider.errorMessage, isNot(contains('PRIVATE_BACKEND_AUTH_TOKEN')));
  });

  test('successful server null result stays a legitimate unavailable stadium',
      () async {
    final repo = _StrictLookupRepository();
    final provider = StadiumProvider(repository: repo);
    addTearDown(provider.dispose);

    final lookup = provider.getStadiumById('missing-pitch');
    repo.result.complete(null);
    expect(await lookup, isNull);
    expect(provider.errorMessage, isNull);
  });
}
