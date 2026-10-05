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
    final files = _dartFiles(Directory('lib/features'));
    final offenders = <String>[];

    for (final file in files) {
      final source = file.readAsStringSync();
      if (source.contains('Supabase.instance.client')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('production Dart code contains no empty catch blocks', () {
    final files = _dartFiles(Directory('lib'));
    final pattern = RegExp(r'catch\s*\([^)]*\)\s*\{\s*\}');
    final offenders = <String>[];

    for (final file in files) {
      final source = file.readAsStringSync();
      if (pattern.hasMatch(source)) {
        offenders.add(file.path);
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
