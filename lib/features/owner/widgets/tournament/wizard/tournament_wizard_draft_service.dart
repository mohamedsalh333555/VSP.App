import 'package:shared_preferences/shared_preferences.dart';

class TournamentWizardDraftService {
  static String getDraftPrefix(String uid) {
    return uid.isNotEmpty ? 'vsp_draft_tournament_${uid}_' : 'temp_tournament_';
  }

  static Future<void> saveDraft({
    required String prefix,
    required String name,
    required String sport,
    required String fee,
    required String prize,
    required String type,
    required String teams,
    required int groups,
    required int qualifying,
    required bool twoLegs,
    DateTime? startDate,
    DateTime? endDate,
    required String duration,
    required int currentStep,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${prefix}name', name);
      await prefs.setString('${prefix}sport', sport);
      await prefs.setString('${prefix}fee', fee);
      await prefs.setString('${prefix}prize', prize);
      await prefs.setString('${prefix}type', type);
      await prefs.setString('${prefix}teams', teams);
      await prefs.setInt('${prefix}groups', groups);
      await prefs.setInt('${prefix}qualifying', qualifying);
      await prefs.setBool('${prefix}two_legs', twoLegs);
      if (startDate != null) {
        await prefs.setString('${prefix}start_date', startDate.toIso8601String());
      } else {
        await prefs.remove('${prefix}start_date');
      }
      if (endDate != null) {
        await prefs.setString('${prefix}end_date', endDate.toIso8601String());
      } else {
        await prefs.remove('${prefix}end_date');
      }
      await prefs.setString('${prefix}duration', duration);
      await prefs.setInt('${prefix}current_step', currentStep);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadDraft(String prefix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'name': prefs.getString('${prefix}name'),
        'sport': prefs.getString('${prefix}sport'),
        'fee': prefs.getString('${prefix}fee'),
        'prize': prefs.getString('${prefix}prize'),
        'type': prefs.getString('${prefix}type'),
        'teams': prefs.getString('${prefix}teams'),
        'groups': prefs.getInt('${prefix}groups'),
        'qualifying': prefs.getInt('${prefix}qualifying'),
        'two_legs': prefs.getBool('${prefix}two_legs'),
        'start_date': prefs.getString('${prefix}start_date'),
        'end_date': prefs.getString('${prefix}end_date'),
        'duration': prefs.getString('${prefix}duration'),
        'current_step': prefs.getInt('${prefix}current_step'),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearDraft(String prefix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        'name', 'sport', 'fee', 'prize', 'type', 'teams',
        'groups', 'qualifying', 'two_legs', 'start_date',
        'end_date', 'duration', 'current_step',
      ];
      for (final k in keys) {
        await prefs.remove('$prefix$k');
        await prefs.remove('temp_tournament_$k');
      }
    } catch (_) {}
  }
}
