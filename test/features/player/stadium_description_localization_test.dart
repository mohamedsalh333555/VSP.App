import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_information_tab.dart';

void main() {
  test('known standalone English rule labels display in Arabic', () {
    expect(
      StadiumInformationTab.localizeKnownDescriptionLabels(
        '• Cleanliness\n• No Smoking\nPunctuality',
        isArabic: true,
      ),
      '• الحفاظ على النظافة\n• ممنوع التدخين\nالالتزام بالمواعيد',
    );
  });

  test('owner prose and English locale are not rewritten', () {
    const text = 'Our Cleanliness standards are high.\n• Parking';
    expect(
      StadiumInformationTab.localizeKnownDescriptionLabels(text, isArabic: true),
      text,
    );
    expect(
      StadiumInformationTab.localizeKnownDescriptionLabels(
        '• No Smoking',
        isArabic: false,
      ),
      '• No Smoking',
    );
  });
  test('English descriptions translate only standalone Arabic stock labels', () {
    const original = '  • الحفاظ على النظافة\n- ممنوع التدخين\nالالتزام بالمواعيد';
    expect(
      StadiumInformationTab.localizeKnownDescriptionLabels(
        original, isArabic: false,
      ),
      '  • Cleanliness\n- No Smoking\nPunctuality',
    );
  });

  test('owner prose containing stock-rule words is never changed', () {
    const original =
        'الحفاظ على النظافة مسؤولية الجميع.\nممنوع التدخين داخل غرف التغيير فقط.\nOur Cleanliness is important.\n• Parking';
    for (final isArabic in [true, false]) {
      expect(
        StadiumInformationTab.localizeKnownDescriptionLabels(
          original, isArabic: isArabic,
        ),
        original,
      );
    }
  });

  test('long multiline descriptions remain untouched without truncation', () {
    final original = List.filled(60, 'Our stadium has great history and facilities.')
        .join('\n');
    for (final isArabic in [true, false]) {
      expect(
        StadiumInformationTab.localizeKnownDescriptionLabels(
          original, isArabic: isArabic,
        ),
        original,
      );
    }
  });

}
