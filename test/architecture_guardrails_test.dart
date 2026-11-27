import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/tokens/vsp_design_tokens.dart';

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
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final ar =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;

    final enKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
    final arKeys = ar.keys.where((key) => !key.startsWith('@')).toSet();

    expect(arKeys.difference(enKeys), isEmpty);
    expect(enKeys.difference(arKeys), isEmpty);

    for (final key in enKeys.intersection(arKeys)) {
      final enText = en[key]?.toString() ?? '';
      final arText = ar[key]?.toString() ?? '';
      final placeholders = RegExp(
        r'\{[^}]+\}',
      ).allMatches(enText).map((m) => m.group(0)).toList()..sort();
      final arabicPlaceholders = RegExp(
        r'\{[^}]+\}',
      ).allMatches(arText).map((m) => m.group(0)).toList()..sort();
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

  test('Legacy vsp_tokens.dart aliases V2 colors instead of duplicating core hex literals', () {
    final legacyTokens = File('lib/core/ui/tokens/vsp_tokens.dart').readAsStringSync();
    expect(legacyTokens.contains('0xFF09090B'), isFalse);
    expect(legacyTokens.contains('0xFF18181B'), isFalse);
    expect(legacyTokens.contains('0xFF27272A'), isFalse);
    expect(legacyTokens.contains('0xFF9FDF02'), isFalse);
    expect(legacyTokens.contains('VSPDSSemanticColors'), isTrue);
    expect(RegExp(r'Color\(0x[0-9A-Fa-f]+\)').hasMatch(legacyTokens), isFalse);
    expect(legacyTokens.contains('BoxShadow('), isFalse);
    expect(legacyTokens.contains('TextStyle('), isFalse);
  });

  test('No non-token Color(0x...) literals exist outside lib/core/ui/tokens/', () {
    final libDir = Directory('lib');
    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.contains('lib/core/ui/tokens/')) continue;
      final content = entity.readAsStringSync();
      if (RegExp(r'Color\(0x[0-9A-Fa-f]+\)').hasMatch(content)) {
        violations.add(normalized);
      }
    }
    expect(violations, isEmpty, reason: 'Use VSPDSColors / VSPDSSemanticColors instead of raw Color(0x...)');
  });

  test('Every *_screen.dart uses SafeArea, VSPScaffold, or VSPScrollPadding', () {
    final libDir = Directory('lib');
    final missingSafe = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_screen.dart')) continue;
      final content = entity.readAsStringSync();
      if (content.contains('Scaffold') &&
          !content.contains('SafeArea') &&
          !content.contains('VSPScaffold') &&
          !content.contains('VSPScrollPadding')) {
        missingSafe.add(entity.path.replaceAll('\\', '/'));
      }
    }
    expect(missingSafe, isEmpty, reason: 'All Scaffold screens must protect safe areas');
  });

  test('Canonical design-tokens.json stays synced with vsp_design_tokens.dart', () {
    final jsonMap = jsonDecode(File('design-tokens.json').readAsStringSync()) as Map<String, dynamic>;
    final colors = jsonMap['colors'] as Map<String, dynamic>;
    String toHex(Color c) =>
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    expect(colors['background'], toHex(VSPDSSemanticColors.background));
    expect(colors['surface'], toHex(VSPDSSemanticColors.surface));
    expect(colors['accent'], toHex(VSPDSSemanticColors.accent));
    expect(colors['textPrimary'], toHex(VSPDSSemanticColors.textPrimary));
    expect(colors['textSecondary'], toHex(VSPDSSemanticColors.textSecondary));
    expect(colors['error'], toHex(VSPDSSemanticColors.error));
    expect(colors['warning'], toHex(VSPDSSemanticColors.warning));
    expect(colors['info'], toHex(VSPDSSemanticColors.info));
    expect(colors['success'], toHex(VSPDSSemanticColors.success));

    final typography = jsonMap['typography'] as Map<String, dynamic>;
    expect(typography['latinFont'], VSPDSTypography.latinFont);
    expect(typography['arabicFont'], VSPDSTypography.arabicFont);
  });

  test('All 6 official Shield PNG assets exist on disk and legacy shield_platinum.png is removed', () {
    for (final tier in ['silver', 'gold', 'diamond', 'elite', 'legendary', 'immortal']) {
      expect(
        File('assets/images/shields/shield_$tier.png').existsSync(),
        isTrue,
        reason: 'Missing shield asset: assets/images/shields/shield_$tier.png',
      );
    }
    expect(
      File('assets/images/shields/shield_platinum.png').existsSync(),
      isFalse,
      reason: 'Legacy shield_platinum.png must be removed',
    );
  });

  test('Brand Rule: #9FDF02 is NOT used for success, focusRing, or shield tiers', () {
    expect(VSPDSSemanticColors.success, isNot(equals(VSPDSColors.voltGreen)));
    expect(VSPDSSemanticColors.focusRing, isNot(equals(VSPDSColors.voltGreen)));
    for (final c in [
      VSPDSColors.tierSilver,
      VSPDSColors.tierGold,
      VSPDSColors.tierDiamond,
      VSPDSColors.tierElite,
      VSPDSColors.tierLegendary,
      VSPDSColors.tierImmortal,
    ]) {
      expect(c, isNot(equals(VSPDSColors.voltGreen)));
    }
  });

  test('Green Policy: No forbidden green hexes (#25D366, #22C55E) exist in lib/', () {
    final forbidden = RegExp(r'(25D366|22C55E)', caseSensitive: false);
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (forbidden.hasMatch(content)) {
        hits.add(entity.path.replaceAll('\\', '/'));
      }
    }
    expect(hits, isEmpty, reason: 'Forbidden green hexes found in: $hits');
  });

  test('Green Policy: VSPAmbientBackground glow is restricted to player_home_screen.dart only', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.endsWith('vsp_ambient_background.dart') || path.endsWith('player_home_screen.dart')) continue;
      final content = entity.readAsStringSync();
      if (content.contains('VSPAmbientBackground') && content.contains('showTopGlow: true')) {
        hits.add(path);
      }
    }
    expect(hits, isEmpty, reason: 'Green ambient glow must ONLY be enabled on player_home_screen.dart');
  });

  test('Green policy: shared decorative tokens are neutral', () {
    expect(VSPDSSemanticColors.accent, VSPDSColors.voltGreen);
    for (final c in [
      VSPDSColors.voltGreenSoft,
      VSPDSColors.voltGreenMuted,
      VSPDSColors.voltGreenBorder,
      VSPDSColors.glassBorderAccent,
      VSPDSColors.glassGlow,
      VSPDSSemanticColors.accentSoft,
      VSPDSSemanticColors.accentBorder,
      VSPDSTypography.priceCompact.color!,
      VSPDSTypography.actionLabel.color!,
    ]) {
      final argb = c.toARGB32();
      final red = (argb >> 16) & 0xff;
      final green = (argb >> 8) & 0xff;
      final blue = argb & 0xff;
      expect(green > red && green > blue, isFalse);
    }
    expect(VSPDSColors.homeAmbientGlow.toARGB32() & 0xFFFFFF,
        VSPDSColors.voltGreen.toARGB32() & 0xFFFFFF);
    final home = File('lib/features/player/screens/player_home_screen.dart').readAsStringSync();
    expect(home, contains('showTopGlow: _selectedIndex == 0'));
    expect(home, contains('showBottomGlow: _selectedIndex == 0'));
    final ambient = File('lib/shared/widgets/vsp_ambient_background.dart').readAsStringSync();
    expect(ambient, contains('this.showTopGlow = false'));
    final nav = File('lib/shared/widgets/vsp_bottom_nav_bar.dart').readAsStringSync();
    expect(nav, isNot(contains('VSPDSSemanticColors.accent')));
    final stadium = File('lib/shared/widgets/stadium_card.dart').readAsStringSync();
    expect(stadium, isNot(contains('VSPColors.accent')));
  });

  test('Green policy: all literal Flutter green colors must be the canonical neon declarations', () {
    final hits = <String>[];
    final literal = RegExp(r'Color\s*\(\s*0x([0-9a-fA-F]{8})\s*\)');
    for (final file in _dartFiles(Directory('lib'))) {
      final path = file.path.replaceAll('\\', '/');
      final source = file.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        final argb = int.parse(match.group(1)!, radix: 16);
        final r = (argb >> 16) & 255;
        final g = (argb >> 8) & 255;
        final b = argb & 255;
        if (g <= r || g <= b) continue;
        final line = source.substring(0, match.start).split('\n').length;
        final canonical = path.endsWith('/vsp_design_tokens.dart') &&
            (argb == 0xFF9FDF02 || argb == 0x1F9FDF02);
        if (!canonical) hits.add('$path:$line');
      }
    }
    expect(hits, isEmpty, reason: 'Unexpected green literals: $hits');
  });

  test('Green policy: canonical hover and payment background stay non-decorative', () {
    final json = jsonDecode(File('design-tokens.json').readAsStringSync()) as Map<String, dynamic>;
    final colors = json['colors'] as Map<String, dynamic>;
    expect(colors['accentHover'], colors['accent']);
    final payment = File('lib/features/player/widgets/payment/payment_background_glow.dart').readAsStringSync();
    expect(payment, isNot(contains('VSPColors.accent')));
    expect(VSPDSComponentEffects.buttonShadow.color.toARGB32() & 0xFFFFFF, 0);
  });
}
