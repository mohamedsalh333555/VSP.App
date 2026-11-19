import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/shared/widgets/vsp_bottom_nav_bar.dart';

const _outline = [
  Iconsax.home_1_copy, Iconsax.people_copy, Iconsax.cup_copy,
  Iconsax.calendar_1_copy, Iconsax.user_copy,
];
const _filled = [
  Iconsax.home_1, Iconsax.people, Iconsax.cup,
  Iconsax.calendar_1, Iconsax.user,
];

void main() {
  for (final arabic in [true, false]) {
    final locale = Locale(arabic ? 'ar' : 'en');
    final titles = arabic
        ? ['الرئيسية', 'الفرق', 'البطولات', 'حجوزاتي', 'حسابي']
        : ['Home', 'Teams', 'Cups', 'Bookings', 'Profile'];

    testWidgets('86.01: five unchanged nav destinations, selected filled and inactive outline ($locale)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = 0;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        home: Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: StatefulBuilder(builder: (context, setState) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: VspBottomNavBar(
              selectedIndex: selected,
              onItemTapped: (index) => setState(() => selected = index),
              items: List.generate(5, (i) => VspNavItem(
                activeIcon: _filled[i],
                inactiveIcon: _outline[i],
                label: titles[i],
              )),
            ),
          )),
        ),
      ));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        expect(find.text(titles[i]), findsOneWidget);
        expect(find.byIcon(i == selected ? _filled[i] : _outline[i]), findsOneWidget);
      }
      await tester.tap(find.text(titles[2]));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(find.byIcon(Iconsax.cup), findsOneWidget);
      expect(find.byIcon(Iconsax.home_1_copy), findsOneWidget);
      expect(find.byIcon(Iconsax.cup_copy), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
