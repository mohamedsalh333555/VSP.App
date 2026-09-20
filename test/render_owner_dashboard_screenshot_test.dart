@Tags(['visual'])
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/features/owner/widgets/dashboard/owner_verification_banner.dart';
import 'package:vsp_application/features/owner/widgets/dashboard/owner_no_stadium_empty_state.dart';

void main() {
  testWidgets('Generate high fidelity owner dashboard screenshot', (WidgetTester tester) async {
    // 1. Load Arabic Fonts (Tajawal)
    final tajawalLoader = FontLoader('Tajawal');
    final regBytes = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
    tajawalLoader.addFont(Future.value(ByteData.view(regBytes.buffer)));
    final medBytes = File('assets/fonts/Tajawal-Medium.ttf').readAsBytesSync();
    tajawalLoader.addFont(Future.value(ByteData.view(medBytes.buffer)));
    final boldBytes = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    tajawalLoader.addFont(Future.value(ByteData.view(boldBytes.buffer)));
    await tajawalLoader.load();

    // 2. Load Iconsax Font
    final iconsaxPath = r'C:\Users\pc\AppData\Local\Pub\Cache\hosted\pub.dev\iconsax_flutter-1.0.1\fonts\FlutterIconsax.ttf';
    if (File(iconsaxPath).existsSync()) {
      final iconBytes = File(iconsaxPath).readAsBytesSync();
      final l1 = FontLoader('packages/iconsax_flutter/FlutterIconsax');
      l1.addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await l1.load();

      final l2 = FontLoader('FlutterIconsax');
      l2.addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await l2.load();
    }

    // Configure exact mobile canvas size
    tester.view.physicalSize = const Size(780, 1688); // 390 x 844 at 2x scale
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final dummyOwner = UserModel(
      uid: 'owner_demo',
      email: 'owner@vsp.app',
      name: 'كابتن محمد سمير',
      role: 'owner',
      phone: '01099887766',
      verificationStatus: 'pending',
      isIdentityVerified: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Tajawal',
          scaffoldBackgroundColor: const Color(0xFF0A0E14),
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF141923),
            primary: Color(0xFF9FDF02),
          ),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0E14),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Status Bar / Brand Line ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: VSPColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(VSPRadius.full),
                                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Iconsax.shield_tick_copy, color: VSPColors.accent, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'VSP شريك معتمد',
                                      style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141923),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Icon(Iconsax.notification_copy, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── هيدر الترحيب بالمالك ──
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 1.5),
                                ),
                                child: const Center(
                                  child: Text(
                                    'م',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text(
                                          'أهلاً بك، كابتن محمد',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'لوحة تحكم إدارة المنشأة والملاعب',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // ── 1. كارت التوثيق ومراجعة المستندات (مع زر "إضافة ملعب" الجديد) ──
                          OwnerVerificationBanner(
                            userModel: dummyOwner,
                            isArabic: true,
                            hasStadiums: false,
                          ),

                          // ── 2. كارت البداية والإرشاد الفخم للمالك الجديد ──
                          const OwnerNoStadiumEmptyState(isArabic: true),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── شريط التنقل السفلي الموحد (Bottom Nav) ──
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141923),
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(icon: Iconsax.element_4_copy, label: 'الرئيسية', isSelected: true),
                        _buildNavItem(icon: Iconsax.cup_copy, label: 'البطولات', isSelected: false),
                        _buildNavItem(icon: Iconsax.messages_2_copy, label: 'المحادثات', isSelected: false),
                        _buildNavItem(icon: Iconsax.calendar_2_copy, label: 'الحجوزات', isSelected: false),
                        _buildNavItem(icon: Iconsax.user_copy, label: 'حسابي', isSelected: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Capture exact golden image
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('owner_dashboard_screenshot.png'),
    );

    // Also copy to artifacts directory for display
    const artifactPath = r'C:\Users\pc\.gemini\antigravity-ide\brain\1288b3a5-eaa0-47a6-b279-ca2e9124e308\owner_dashboard_screenshot.png';
    final generatedFile = File('test/owner_dashboard_screenshot.png');
    if (generatedFile.existsSync()) {
      generatedFile.copySync(artifactPath);
      print('SUCCESS: Screenshot copied to artifact directory: $artifactPath');
    }
  });
}

Widget _buildNavItem({
  required IconData icon,
  required String label,
  required bool isSelected,
}) {
  final color = isSelected ? VSPColors.accent : Colors.white38;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ],
  );
}
