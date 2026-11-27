import 'dart:io';
import 'package:flutter/foundation.dart';
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

/// Golden comparator with a strict 0.8% subpixel anti-aliasing tolerance to
/// account for Skia rasterizer differences between Windows and Linux CI while
/// still catching any real layout, color, or typography regression.
class VspGoldenFileComparator extends LocalFileComparator {
  final double tolerance;

  VspGoldenFileComparator(
    super.testFile, {
    this.tolerance = 0.008,
  });

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= tolerance) {
      debugPrint(
        'Golden $golden passed within cross-OS raster tolerance '
        '(${(result.diffPercent * 100).toStringAsFixed(2)}% <= ${(tolerance * 100).toStringAsFixed(2)}%).',
      );
      return true;
    }
    if (!result.passed) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return result.passed;
  }
}
