import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles(Directory root) {
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

void main() {
  test('feature layer does not access Supabase client directly', () {
    const knownLegacyAllowlist = {
      'lib/features/owner/screens/owner_dashboard_screen.dart',
      'lib/features/owner/screens/owner_ledger_screen.dart',
      'lib/features/owner/widgets/brackets/tournament_score_modal.dart',
      'lib/features/player/screens/payment_gateway_screen.dart',
      'lib/features/player/screens/paymob_web_view_screen.dart',
      'lib/features/player/screens/tournament_registration_success_screen.dart',
      'lib/features/player/services/payment_checkout_coordinator.dart',
    };

    final files = _dartFiles(Directory('lib/features'));
    final offenders = <String>[];

    for (final file in files) {
      final normalized = file.path.replaceAll('\\', '/');
      if (knownLegacyAllowlist.contains(normalized)) continue;
      final source = file.readAsStringSync();
      if (source.contains('Supabase.instance.client')) {
        offenders.add(normalized);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('production Dart code contains no empty catch blocks', () {
    const knownLegacyAllowlist = {
      'lib/main.dart',
      'lib/core/providers/auth/auth_draft_cleaner.dart',
      'lib/core/providers/auth/auth_realtime_coordinator.dart',
      'lib/core/providers/auth/auth_registration_service.dart',
      'lib/core/providers/auth/auth_sign_out_handler.dart',
      'lib/core/providers/auth/auth_user_data_fetcher.dart',
      'lib/core/repositories/match_repository.dart',
      'lib/core/repositories/tournament/tournament_match_coordinator.dart',
      'lib/core/repositories/tournament/tournament_query_coordinator.dart',
      'lib/core/repositories/tournament/tournament_registration_coordinator.dart',
      'lib/core/repositories/tournament/tournament_roster_coordinator.dart',
      'lib/core/services/auth_service.dart',
      'lib/core/services/location_service.dart',
      'lib/core/services/notification_service.dart',
      'lib/core/services/remote_config_service.dart',
      'lib/core/services/vsp_copilot_service.dart',
      'lib/core/services/auth/social_auth_service.dart',
      'lib/core/utils/roster_parser_utils.dart',
      'lib/core/widgets/shimmer_image.dart',
      'lib/features/owner/screens/create_tournament_wizard.dart',
      'lib/features/owner/screens/owner_documentation_wizard.dart',
      'lib/features/owner/widgets/owner_booking_sheet.dart',
      'lib/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart',
      'lib/features/owner/widgets/add_stadium/stadium_wizard_image_service.dart',
      'lib/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart',
      'lib/features/owner/widgets/tournament/wizard/tournament_wizard_draft_service.dart',
      'lib/features/player/screens/notifications_center_screen.dart',
      'lib/features/player/screens/stadium_details_screen.dart',
      'lib/features/player/screens/support_ticket_screen.dart',
      'lib/features/player/widgets/collective_match_invite_sheet.dart',
      'lib/features/player/widgets/league/team_league_tab.dart',
    };

    final files = _dartFiles(Directory('lib'));
    final pattern = RegExp(r'catch\s*\([^)]*\)\s*\{\s*\}');
    final offenders = <String>[];

    for (final file in files) {
      final normalized = file.path.replaceAll('\\', '/');
      if (knownLegacyAllowlist.contains(normalized)) continue;
      final source = file.readAsStringSync();
      if (pattern.hasMatch(source)) {
        offenders.add(normalized);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Arabic and English ARB catalogs stay key-compatible', () {
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final ar = jsonDecode(
      File('lib/l10n/app_ar.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    final enKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
    final arKeys = ar.keys.where((key) => !key.startsWith('@')).toSet();

    expect(arKeys.difference(enKeys), isEmpty);
    expect(enKeys.difference(arKeys), isEmpty);

    for (final key in enKeys.intersection(arKeys)) {
      final enText = en[key]?.toString() ?? '';
      final arText = ar[key]?.toString() ?? '';
      final placeholders = RegExp(r'\{[^}]+\}')
          .allMatches(enText)
          .map((m) => m.group(0))
          .toList()
        ..sort();
      final arabicPlaceholders = RegExp(r'\{[^}]+\}')
          .allMatches(arText)
          .map((m) => m.group(0))
          .toList()
        ..sort();
      expect(
        arabicPlaceholders,
        placeholders,
        reason: 'Placeholder mismatch for $key',
      );
    }
  });

  test('test sources are not excluded from analyzer configuration', () {
    final source = File('analysis_options.yaml').readAsStringSync();
    expect(source.contains('test/**'), isFalse);
  });
}
