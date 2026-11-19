import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tournament refund worker has distinct claims for all three queues', () {
    final worker = File(
      'supabase/functions/process_tournament_refund/index.ts',
    ).readAsStringSync();
    for (final rpc in <String>[
      'claim_next_cancellation_refund_atomic',
      'claim_next_1v1_cancellation_refund_atomic',
      'claim_next_team_league_cancellation_refund_atomic',
    ]) {
      expect(worker, contains(rpc), reason: 'Missing queue consumer $rpc');
    }
    for (final queue in <String>[
      'cancellation_refund_queue',
      'vsp_1v1_cancellation_refund_queue',
      'team_league_cancellation_refund_queue',
    ]) {
      expect(worker, contains('from("$queue")'));
    }
  });

  test('staging refund readiness audit does not disclose secret value', () {
    final sql = File(
      'supabase/tests/read_only_staging_financial_audit.sql',
    ).readAsStringSync();
    expect(sql, contains("name='refund_worker'"));
    expect(sql, isNot(contains('select secret')));
    expect(sql.toLowerCase(), isNot(contains('delete from')));
    expect(sql.toLowerCase(), isNot(contains('update public')));
    expect(sql.toLowerCase(), isNot(contains('insert into')));
  });
}
