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
}
