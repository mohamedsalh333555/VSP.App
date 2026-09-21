import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/features/copilot/widgets/copilot_starter_prompts.dart';
import 'package:vsp_application/shared/widgets/gemini_ai_icon.dart';

void main() {
  testWidgets('Render Copilot Screen Screenshot', (WidgetTester tester) async {
    // 1. Load Arabic Tajawal font
    try {
      final tajawalLoader = FontLoader('Tajawal');
      final regFile = File(r'K:\.gemini\antigravity\scratch\vsp_application\assets\fonts\Tajawal-Regular.ttf');
      if (regFile.existsSync()) {
        final regBytes = regFile.readAsBytesSync();
        tajawalLoader.addFont(Future.value(ByteData.view(regBytes.buffer)));
      }
      final boldFile = File(r'K:\.gemini\antigravity\scratch\vsp_application\assets\fonts\Tajawal-Bold.ttf');
      if (boldFile.existsSync()) {
        final boldBytes = boldFile.readAsBytesSync();
        tajawalLoader.addFont(Future.value(ByteData.view(boldBytes.buffer)));
      }
      await tajawalLoader.load();
    } catch (e) {
      debugPrint('Font load notice: $e');
    }

    // 2. Load Iconsax font
    try {
      final iconsaxPath = r'C:\Users\pc\AppData\Local\Pub\Cache\hosted\pub.dev\iconsax_flutter-1.0.1\fonts\FlutterIconsax.ttf';
      final file = File(iconsaxPath);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        for (final family in ['packages/iconsax_flutter/iconsax', 'iconsax', 'FlutterIconsax', 'packages/iconsax_flutter/FlutterIconsax']) {
          final loader = FontLoader(family);
          loader.addFont(Future.value(ByteData.view(bytes.buffer)));
          await loader.load();
        }
      }
    } catch (e) {
      debugPrint('Iconsax font load notice: $e');
    }

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Tajawal',
          scaffoldBackgroundColor: VSPColors.background,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: VSPColors.background,
            body: RepaintBoundary(
              key: repaintKey,
              child: SizedBox(
                width: 411,
                height: 914,
                child: Scaffold(
                  backgroundColor: VSPColors.background,
                  appBar: AppBar(
                    backgroundColor: VSPColors.surface,
                    elevation: 0,
                    centerTitle: true,
                    leading: Center(
                      child: Container(
                        width: 33,
                        height: 33,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Iconsax.arrow_right_3_copy,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GeminiAIIcon(size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'كابتن VSP الذكي',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: VSPColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    actions: const [
                      IconButton(
                        icon: Icon(Iconsax.messages_2_copy, color: VSPColors.textPrimary, size: 20),
                        onPressed: null,
                      ),
                      IconButton(
                        icon: Icon(Iconsax.add_circle_copy, color: VSPColors.textPrimary, size: 22),
                        onPressed: null,
                      ),
                      SizedBox(width: 6),
                    ],
                  ),
                  body: Column(
                    children: [
                      Expanded(
                        child: CopilotStarterPrompts(
                          onSelectPrompt: (_) {},
                          isArabic: true,
                        ),
                      ),
                      // Input Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          color: VSPColors.surface,
                          border: Border(top: BorderSide(color: VSPColors.borderLight, width: 1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: VSPColors.inputFill,
                                  borderRadius: BorderRadius.circular(VSPRadius.input),
                                  border: Border.all(color: VSPColors.borderLight),
                                ),
                                child: const Text(
                                  'اسأل كابتن VSP عن الملاعب والبطولات...',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: VSPColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: VSPColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Iconsax.send_2_copy, color: Colors.black, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final RenderRepaintBoundary boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    const outputPath = r'C:\Users\pc\.gemini\antigravity-ide\brain\c8f1dbc6-d6de-4fac-9ad9-335b131b316c\vsp_copilot_screen.png';
    File(outputPath).writeAsBytesSync(pngBytes);
    debugPrint('CAPTURED_CLEAN_SCREENSHOT_${pngBytes.length}');
    exit(0);
  });
}
