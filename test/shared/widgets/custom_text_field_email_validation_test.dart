import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/shared/widgets/custom_text_field.dart';

void main() {
  testWidgets('email success indicator matches auth submission validation',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomTextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
        ),
      ),
    ));
    expect(find.byIcon(Iconsax.tick_circle_copy), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'player@host.c');
    await tester.pumpAndSettle();
    expect(find.byIcon(Iconsax.tick_circle_copy), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'player+cup@example.com');
    await tester.pumpAndSettle();
    expect(find.byIcon(Iconsax.tick_circle_copy), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'player@@example.com');
    await tester.pumpAndSettle();
    expect(find.byIcon(Iconsax.tick_circle_copy), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    controller.dispose();
  });
}
