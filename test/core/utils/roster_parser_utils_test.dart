import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/roster_parser_utils.dart';

void main() {
  group('WhatsApp roster import', () {
    test('strips western, Arabic-Indic and Persian numbering', () {
      expect(
        RosterParserUtils.parseSquadText('1- أحمد محمود\n٢. كابتن علي\n۳) محمود علي'),
        ['أحمد محمود', 'علي', 'محمود علي'],
      );
    });
    test('preserves names without numbers and removes repeated players', () {
      expect(
        RosterParserUtils.parseSquadText('محمد أحمد\n• محمد أحمد\n- سيف حسن'),
        ['محمد أحمد', 'سيف حسن'],
      );
    });
    test('ignores list headers and numeric-only rows', () {
      expect(
        RosterParserUtils.parseSquadText('تشكيلة الفريق:\n١\n٢-\n3- علي سالم\n'),
        ['علي سالم'],
      );
    });
  });
}
