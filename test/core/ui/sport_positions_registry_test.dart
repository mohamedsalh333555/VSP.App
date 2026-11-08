import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';

void main() {
  test('football registry exposes four stable localized position codes', () {
    final positions = SportPositionsRegistry.getPositionsForSport('Football');
    expect(positions.map((position) => position.code).toList(),
        ['GK', 'DF', 'MF', 'FW']);
    expect(positions.every((position) =>
        position.nameAr.isNotEmpty && position.nameEn.isNotEmpty), isTrue);
    expect(SportPositionsRegistry.getDefaultPosition('Football'), 'FW');
  });

  test('defaults belong to the sport-specific available position codes', () {
    for (final sport in ['Football', 'Padel', 'Basketball', 'Volleyball', 'Handball']) {
      final available = SportPositionsRegistry.getPositionsForSport(sport)
          .map((position) => position.code).toSet();
      expect(available, contains(SportPositionsRegistry.getDefaultPosition(sport)),
          reason: sport);
    }
  });

  test('unknown sports safely reuse football options', () {
    final fallback = SportPositionsRegistry.getPositionsForSport('Unknown');
    expect(fallback.map((position) => position.code).toList(),
        ['GK', 'DF', 'MF', 'FW']);
  });
}
