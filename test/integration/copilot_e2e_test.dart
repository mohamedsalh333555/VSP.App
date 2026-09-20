import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/services/vsp_copilot_service.dart';
import 'package:vsp_application/features/copilot/screens/vsp_copilot_screen.dart';
import 'package:vsp_application/features/copilot/widgets/copilot_chat_bubble.dart';

void main() {
  group('Copilot E2E - Complete User Journey & Widget Integration', () {
    late VspCopilotService copilotService;

    setUp(() {
      copilotService = const VspCopilotService();
      copilotService.resetRateLimiter();
    });

    // ==================== الرحلة الكاملة للمستخدم ====================
    testWidgets('Complete Booking Journey via Copilot Widget Tree', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StadiumProvider>(create: (_) => StadiumProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            home: VspCopilotScreen(
              copilotService: copilotService,
              isArabic: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. تحقق من ظهور عنوان كابتن VSP والأسئلة الافتراضية
      expect(find.text('كابتن VSP الذكي'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);

      // 2. اكتب طلب بحث
      await tester.enterText(
        find.byType(TextField),
        'ملاعب في المعادي بسعر تحت 400 جنيه',
      );
      await tester.pump();

      // اضغط إرسال
      await tester.tap(find.byIcon(Iconsax.send_2_copy));
      await tester.pumpAndSettle();

      // 3. تحقق من ظهور فقاعات الدردشة والرد
      expect(find.byType(CopilotChatBubble), findsWidgets);
      expect(find.textContaining('المعادي'), findsWidgets);

      // 4. تحقق من ظهور بطاقة ملعب قابلة للحجز.
      // The stadium results use a horizontal ListView, so make the booking
      // control visible before asserting it exists in the rendered tree.
      final bookButton = find.text('احجز', skipOffstage: false);
      if (bookButton.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          bookButton,
          200,
          scrollable: find.byType(Scrollable).last,
        );
      }
      expect(bookButton, findsWidgets);
    });

    // ==================== اختبار الردود المتعددة والذاكرة ====================
    testWidgets('Multi-Turn Conversation Retention & Memory', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StadiumProvider>(create: (_) => StadiumProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            home: VspCopilotScreen(
              copilotService: copilotService,
              isArabic: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // الرسالة الأولى: تحديد المحافظة
      await tester.enterText(find.byType(TextField), 'ملاعب في الجيزة');
      await tester.tap(find.byIcon(Iconsax.send_2_copy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CopilotChatBubble), findsWidgets);

      // الرسالة الثانية: فلترة السعر مع الحفاظ على الجيزة
      await tester.enterText(find.byType(TextField), 'بس اللي بتحت 350');
      await tester.tap(find.byIcon(Iconsax.send_2_copy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // تحقق من أن الرد يتذكر السياق ويظهر في الشاشة
      expect(find.byType(CopilotChatBubble), findsWidgets);
      expect(find.textContaining('الجيزة'), findsWidgets);
    });
  });
}
