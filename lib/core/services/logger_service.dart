import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class VSPLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: false,
      printEmojis: true,
    ),
  );

  static void d(String message) {
    try {
      _logger.d(message);
    } catch (e) {
      debugPrint('[DEBUG] $message');
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    try {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } catch (e) {
      debugPrint('[ERROR] $message: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  static void i(String message) {
    try {
      _logger.i(message);
    } catch (e) {
      debugPrint('[INFO] $message');
    }
  }

  static void w(String message) {
    try {
      _logger.w(message);
    } catch (e) {
      debugPrint('[WARN] $message');
    }
  }
}
