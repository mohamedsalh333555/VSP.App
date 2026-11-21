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

  /// Missing or malformed event prices are unknown; actual zero is valid.
  static String publishedCapacity(Map<String, dynamic> cup) {
    final capacity = cup['max_teams'];
    return capacity is int && capacity > 0 && capacity <= 1000
        ? capacity.toString() : '—';
  }

  static String publishedFee(Map<String, dynamic> cup) {
    final value = cup['hospitality_fee'];
    num? amount;
    if (value is num) {
      amount = value;
    } else if (value is String &&
        RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value.trim())) {
      amount = num.tryParse(value.trim());
    }
    return amount == null || !amount.isFinite || amount < 0
        ? '—' : amount.toString();
  }

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
      // An unlabeled entry is not an officially announced prize.
      if (label == null || label.isEmpty) continue;
      final safeLabel = label.length > 120
          ? '${label.substring(0, 120)}…' : label;
      if (!out.contains(safeLabel)) out.add(safeLabel);
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
    final teams = publishedCapacity(cup);
    final fee = publishedFee(cup);
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
        Text(fee == '—'
            ? (isArabic ? 'ضيافة الفريق: غير معلنة' : 'Team hospitality: Not announced')
            : (isArabic ? 'ضيافة الفريق: $fee جنيه' : 'Team hospitality: $fee EGP')),
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
