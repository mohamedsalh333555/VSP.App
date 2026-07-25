import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_settings_model.dart';

class AppSettingsRepository {
  static final AppSettingsRepository _instance = AppSettingsRepository._internal();
  factory AppSettingsRepository() => _instance;
  AppSettingsRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  AppSettings? _cachedSettings;

  /// Returns cached settings or fetches fresh dynamic configuration from Supabase
  Future<AppSettings> getSettings({bool forceRefresh = false}) async {
    if (_cachedSettings != null && !forceRefresh) {
      return _cachedSettings!;
    }

    try {
      final response = await _supabase
          .from('app_settings')
          .select()
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response != null) {
        _cachedSettings = AppSettings.fromMap(response);
        return _cachedSettings!;
      }
    } catch (e) {
      debugPrint('AppSettingsRepository: Using fallback settings due to: $e');
    }

    _cachedSettings ??= const AppSettings();
    return _cachedSettings!;
  }

  /// Updates app settings on Supabase (Admin usage)
  Future<bool> updateSettings(AppSettings settings) async {
    try {
      await _supabase.from('app_settings').upsert(settings.toMap());
      _cachedSettings = settings;
      return true;
    } catch (e) {
      debugPrint('AppSettingsRepository: Error updating settings: $e');
      return false;
    }
  }
}
