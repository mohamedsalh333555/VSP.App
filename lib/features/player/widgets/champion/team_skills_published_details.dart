import 'package:flutter/material.dart';

/// Published fields from the live Team Skills Cup row, never a locally
/// assumed fixture or a hard-coded promise of fees/prizes.
class TeamSkillsPublishedDetails extends StatelessWidget {
  final Map<String, dynamic> cup;
  final String? stadiumName;
  final bool isArabic;

  const TeamSkillsPublishedDetails({
    super.key,
    required this.cup,
    required this.stadiumName,
    required this.isArabic,
  });

  static List<String> publishedPrizeLabels(
    Map<String, dynamic> cup, {required bool isArabic}
  ) {
    final prizes = cup['prizes'];
    if (prizes is! List) return const [];
    final out = <String>[];
    for (var i = 0; i < prizes.length; i++) {
      final item = prizes[i];
      String? label;
      if (item is String) {
        label = item.trim();
      } else if (item is Map) {
        final fields = isArabic
            ? ['title_ar', 'name_ar', 'award_ar', 'prize_ar', 'title', 'name', 'award', 'prize']
            : ['title', 'name', 'award', 'prize', 'title_ar', 'name_ar', 'award_ar', 'prize_ar'];
        for (final key in fields) {
          final candidate = item[key];
          if (candidate is String && candidate.trim().isNotEmpty) {
            label = candidate.trim();
            break;
          }
        }
      }
      // Unknown prize JSON is never dumped as a raw object to players.
      out.add(label == null || label.isEmpty
          ? (isArabic ? 'جائزة ${i + 1}' : 'Prize ${i + 1}')
          : label.length > 120 ? '${label.substring(0, 120)}…' : label);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(cup['starts_at']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(cup['ends_at']?.toString() ?? '')?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    String localTime(DateTime? value) {
      if (value == null) return isArabic ? 'غير محدد' : 'Not specified';
      final date = localizations.formatMediumDate(value);
      final time = localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true);
      return '$date • $time';
    }
    final region = cup['governorate']?.toString().trim() ?? '';
    final venue = stadiumName?.trim() ?? '';
    final teams = cup['max_teams']?.toString() ?? '—';
    final fee = cup['hospitality_fee']?.toString() ?? '—';
    final prizes = publishedPrizeLabels(cup, isArabic: isArabic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isArabic ? 'المحافظة: ${region.isEmpty ? 'غير محددة' : region}'
            : 'Governorate: ${region.isEmpty ? 'Not specified' : region}'),
        const SizedBox(height: 4),
        Text(isArabic ? 'الملعب: ${venue.isEmpty ? 'اسم الملعب غير متاح' : venue}'
            : 'Venue: ${venue.isEmpty ? 'Venue name unavailable' : venue}'),
        const SizedBox(height: 4),
        Text(isArabic ? 'البداية: ${localTime(start)}' : 'Starts: ${localTime(start)}'),
        const SizedBox(height: 4),
        Text(isArabic ? 'النهاية: ${localTime(end)}' : 'Ends: ${localTime(end)}'),
        const SizedBox(height: 4),
        Text(isArabic ? 'عدد الفرق الأقصى: $teams' : 'Maximum teams: $teams'),
        const SizedBox(height: 4),
        Text(isArabic ? 'ضيافة الفريق: $fee جنيه' : 'Team hospitality: $fee EGP'),
        const SizedBox(height: 4),
        Text(isArabic ? 'الأوقات حسب توقيت جهازك' : 'Times in your device timezone',
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(isArabic ? 'الجوائز المعلنة' : 'Published prizes',
            style: Theme.of(context).textTheme.titleSmall),
        if (prizes.isEmpty)
          Text(isArabic ? 'لم يتم الإعلان عن جوائز بعد'
              : 'No prizes have been announced'),
        ...prizes.map((prize) => Text('• $prize')),
      ],
    );
  }
}
