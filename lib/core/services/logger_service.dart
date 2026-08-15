import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class VSPLogger {
  static final Logger _logger = Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    printer: PrettyPrinter(
      methodCount: kReleaseMode ? 0 : 2,
      errorMethodCount: 5,
      lineLength: 80,
      colors: !kReleaseMode,
      printEmojis: true,
    ),
  );

  static void d(String message) {
    if (!kReleaseMode) {
      _logger.d(message);
    }
  }

  static void i(String message) {
    if (!kReleaseMode) {
      _logger.i(message);
    }
  }

  static void w(String message) {
    _logger.w(message);
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
