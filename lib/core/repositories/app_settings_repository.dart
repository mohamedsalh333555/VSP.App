import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_settings_model.dart';

class AppSettingsRepository {
  static final AppSettingsRepository _instance = AppSettingsRepository._internal();
  factory AppSettingsRepository() => _instance;
  AppSettingsRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  /// Supabase is authoritative. Cache is only an in-process optimization after a successful read.
  Future<AppSettings> getSettings({bool forceRefresh = false}) async { // forceRefresh kept for API compatibility; Supabase is always read.
    final response = await _supabase
        .from('app_settings')
        .select()
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 5));

    if (response == null) {
      throw StateError('VSP app settings are unavailable in Supabase.');
    }

    return AppSettings.fromMap(response);
  }

  Future<bool> updateSettings(AppSettings settings) async {
    try {
      await _supabase.from('app_settings').upsert(settings.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }
}
