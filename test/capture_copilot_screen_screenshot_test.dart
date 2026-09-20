import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/models/copilot_message.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/services/vsp_copilot_service.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/features/copilot/screens/vsp_copilot_screen.dart';

class _MockCopilotService extends VspCopilotService {
  const _MockCopilotService();

  @override
  Future<List<CopilotConversation>> fetchConversations() async => [];

  @override
  Future<List<CopilotMessage>> fetchMessages(String conversationId) async => [];

  @override
  Future<bool> deleteConversation(String conversationId) async => true;
}

void main() {
  testWidgets('Capture real screenshot of VspCopilotScreen', (WidgetTester tester) async {
    // 1. Load Arabic Tajawal font
    try {
      final fontLoader = FontLoader('Tajawal');
      final regularFile = File('assets/fonts/Tajawal-Regular.ttf');
      if (regularFile.existsSync()) {
        final regularBytes = await regularFile.readAsBytes();
        fontLoader.addFont(Future.value(ByteData.view(regularBytes.buffer)));
      }
      final boldFile = File('assets/fonts/Tajawal-Bold.ttf');
      if (boldFile.existsSync()) {
        final boldBytes = await boldFile.readAsBytes();
        fontLoader.addFont(Future.value(ByteData.view(boldBytes.buffer)));
      }
      await fontLoader.load();
    } catch (e) {
      debugPrint('Font load notice: $e');
    }

    // 2. Load Iconsax font
    try {
      final fontPath = 'C:/Users/pc/AppData/Local/Pub/Cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf';
      final file = File(fontPath);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        for (final family in ['packages/iconsax_flutter/FlutterIconsax', 'FlutterIconsax', 'iconsax']) {
          final loader = FontLoader(family);
          loader.addFont(Future.value(ByteData.view(bytes.buffer)));
          await loader.load();
        }
      }
    } catch (e) {
      debugPrint('Iconsax load notice: $e');
    }

    // Match typical modern smartphone resolution (393 x 852 physical 1179 x 2556)
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StadiumProvider>(create: (_) => StadiumProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Tajawal',
            scaffoldBackgroundColor: VSPColors.background,
          ),
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: VSPColors.background,
              body: RepaintBoundary(
                key: repaintKey,
                child: const VspCopilotScreen(
                  copilotService: _MockCopilotService(),
                  isArabic: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Pump frames cleanly
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final RenderRepaintBoundary boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    const outputPath = r'C:\Users\pc\.gemini\antigravity-ide\brain\c8f1dbc6-d6de-4fac-9ad9-335b131b316c\vsp_copilot_screen.png';
    File(outputPath).writeAsBytesSync(pngBytes);
    debugPrint('Screenshot captured successfully! Size: ${pngBytes.length} bytes');
  });
}
