import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

/// Loads the bundled VSP fonts (`Poppins` and `Tajawal`) into the Flutter test
/// engine so Golden snapshots render real typography instead of Ahem blocks.
Future<void> loadVspTestFonts() async {
  if (_fontsLoaded) return;

  Future<void> loadFamily(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
    }
    await loader.load();
  }

  await loadFamily('Poppins', const [
    'assets/fonts/Poppins-Regular.ttf',
    'assets/fonts/Poppins-Medium.ttf',
    'assets/fonts/Poppins-Bold.ttf',
  ]);
  await loadFamily('Tajawal', const [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Medium.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);

  _fontsLoaded = true;
}
