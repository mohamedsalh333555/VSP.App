import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Auto Schedule banner and action triggers for a tournament round.
class TournamentRoundAutoScheduleBanner extends StatelessWidget {
  final Championship championship;
  final int roundIndex;
  final List<TournamentMatch> matches;
  final String roundName;
  final VoidCallback onRefresh;

  const TournamentRoundAutoScheduleBanner({
    super.key,
    required this.championship,
    required this.roundIndex,
    required this.matches,
    required this.roundName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bool hasScheduledMatches = matches.any((m) => m.scheduledTime != null);
    final bool isRoundStartedOrFinished = matches.any((m) => m.winnerId != null || m.homeScore != null);

    // Locked if matches in this round have already started or finished
    if (isRoundStartedOrFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'جدول مباريات $roundName (مُغلق )' : '$roundName Schedule (Locked )',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'تم بدء مباريات هذا الدور وتسجيل نتائجها (لا يمكن إعادة الجدولة التلقائية)'
                        : 'Matches in this round have started (Auto-scheduling locked)',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.magic_star_copy, color: VSPColors.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? (hasScheduledMatches ? 'تعديل جدول $roundName' : 'جدولة تلقائية لمباريات $roundName')
                      : (hasScheduledMatches ? 'Manage $roundName Schedule' : 'Auto-Schedule $roundName'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? (hasScheduledMatches
                          ? 'تم جدولة مباريات هذا الدور. يمكنك التصفير أو إعادة الجدولة'
                          : 'توليد المواعيد والتواريخ تلقائياً لـ ${matches.length} مباراة')
                      : (hasScheduledMatches
                          ? 'Matches scheduled. You can reset or re-schedule.'
                          : 'Auto generate dates for ${matches.length} matches'),
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (hasScheduledMatches) ...[
            IconButton(
              tooltip: isArabic ? 'تصفير الجدول وإلغاء المواعيد ' : 'Reset Round Schedule',
              icon: const Icon(Iconsax.rotate_left_copy, color: VSPColors.error, size: 16),
              onPressed: () {
                showResetRoundScheduleConfirmationDialog(
                  context,
                  championshipId: championship.id,
                  roundIndex: roundIndex,
                  matches: matches,
                  roundName: roundName,
                  onScheduleReset: onRefresh,
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () {
              showAutoScheduleModalSheet(
                context,
                championship: championship,
                roundIndex: roundIndex,
                matches: matches,
                roundName: roundName,
                onScheduleSaved: onRefresh,
              );
            },
            child: Text(
              isArabic
                  ? (hasScheduledMatches ? 'إعادة الجدولة ' : 'جدولة ')
                  : (hasScheduledMatches ? 'Re-Schedule ' : 'Schedule '),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reset round match schedule confirmation dialog.
void showResetRoundScheduleConfirmationDialog(
  BuildContext context, {
  required String championshipId,
  required int roundIndex,
  required List<TournamentMatch> matches,
  required String roundName,
  required VoidCallback onScheduleReset,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.rotate_left_copy, color: VSPColors.warning, size: 18),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'تصفير جدول $roundName' : 'Reset $roundName Schedule',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت تأكد من إلغاء وتصفير مواعيد جميع مباريات ($roundName) وإعادتها إلى "غير مجدول"؟'
              : 'Are you sure you want to reset all match dates for ($roundName) to unscheduled?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await TournamentRepository().clearRoundMatchSchedules(
                championshipId: championshipId,
                roundIndex: roundIndex,
                matches: matches,
              );

              if (success && context.mounted) {
                onScheduleReset();
                VSPFeedback.showSuccess(
                  context,
                  isArabic
                      ? ' تم تصفير وإلغاء جدول مباريات $roundName بنجاح!'
                      : ' Reset schedule for $roundName successfully!',
                );
              }
            },
            child: Text(isArabic ? 'تأكيد التصفير ' : 'Confirm Reset'),
          ),
        ],
      );
    },
  );
}

/// Modal bottom sheet to configure auto-scheduling parameters.
void showAutoScheduleModalSheet(
  BuildContext context, {
  required Championship championship,
  required int roundIndex,
  required List<TournamentMatch> matches,
  required String roundName,
  required VoidCallback onScheduleSaved,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  int daysCount = 1;
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);
  final int presetDuration = championship.matchDuration;
  int selectedMatchDuration = presetDuration;

  final List<int> durationOptions = [15, 20, 30, 45, 60, 90];
  if (!durationOptions.contains(presetDuration)) {
    durationOptions.add(presetDuration);
    durationOptions.sort();
  }

  List<int> availableDaysOptions = [1];
  if (matches.length >= 8) {
    availableDaysOptions = [1, 2, 4];
  } else if (matches.length >= 4) {
    availableDaysOptions = [1, 2];
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalCtx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final matchesPerDay = (matches.length / daysCount).ceil();

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).padding.bottom + 20),
            decoration: const BoxDecoration(
              color: VSPColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
                      child: const Icon(Iconsax.magic_star_copy, color: Colors.black, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isArabic ? 'الجدولة التلقائية ($roundName)' : 'Auto Schedule ($roundName)',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const Divider(color: VSPColors.divider),
                const SizedBox(height: 14),

                // 1. Days Distribution Options
                Text(
                  isArabic
                      ? 'كيف تريد توزيع مباريات الدور (${matches.length} مباراة)؟'
                      : 'How to divide ${matches.length} matches?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: availableDaysOptions.map((d) {
                    final isSelected = daysCount == d;
                    final mPerD = (matches.length / d).ceil();

                    String title = isArabic
                        ? (d == 1 ? 'يوم واحد' : (d == 2 ? 'يومان' : '4 أيام'))
                        : (d == 1 ? '1 Day' : '$d Days');
                    String subtitle = isArabic ? '$mPerD مباريات/يوم' : '$mPerD matches/day';
                    if (d == 1) subtitle = isArabic ? '$mPerD مباراة' : '$mPerD matches';

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => daysCount = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? VSPColors.accent : VSPColors.surface,
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                            border: Border.all(
                                color: isSelected ? VSPColors.accent : VSPColors.divider, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Iconsax.calendar_1_copy,
                                color: isSelected ? Colors.black : VSPColors.accent,
                                size: 16,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.black87 : VSPColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 2. Start Date & Start Time Pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isArabic ? 'تاريخ أول مباراة:' : 'Start Date:',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (d != null) setModalState(() => selectedDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: VSPColors.surface,
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(color: VSPColors.divider),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(selectedDate),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const Icon(Iconsax.calendar_1_copy, color: VSPColors.accent, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isArabic ? 'وقت أول مباراة:' : 'Start Time:',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: selectedTime);
                              if (t != null) setModalState(() => selectedTime = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: VSPColors.surface,
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(color: VSPColors.divider),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedTime.format(context),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Match Duration Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'مدة المباراة / الفاصل:' : 'Match Duration:',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: DropdownButton<int>(
                        value: selectedMatchDuration,
                        underline: const SizedBox(),
                        dropdownColor: VSPColors.surface,
                        style: const TextStyle(
                            color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                        items: durationOptions.map((mins) {
                          return DropdownMenuItem<int>(
                            value: mins,
                            child: Text(
                              mins == presetDuration ? '$mins دقيقة (إعدادات البطولة)' : '$mins دقيقة',
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedMatchDuration = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Summary Preview Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            isArabic ? 'ملخص الجدولة التلقائية:' : 'Schedule Summary:',
                            style: const TextStyle(
                                color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                            ? '• سيتم إدراج $matchesPerDay ${matchesPerDay == 1 ? 'مباراة' : 'مباريات'} يومياً على مدار ${daysCount == 1 ? 'يوم واحد' : (daysCount == 2 ? 'يومين' : '$daysCount أيام')}.'
                            : '• $matchesPerDay matches daily over $daysCount day(s).',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isArabic
                            ? '• تبدأ المباريات يومياً الساعة ${selectedTime.format(context)} بفاصل $selectedMatchDuration دقيقة.'
                            : '• Matches start at ${selectedTime.format(context)} with $selectedMatchDuration min interval.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: isArabic ? 'تأكيد وحفظ الجدولة التلقائية ' : 'Save Auto-Schedule ',
                    onPressed: () async {
                      Navigator.pop(modalCtx);
                      final success = await TournamentRepository().autoScheduleRoundMatches(
                        championshipId: championship.id,
                        roundIndex: roundIndex,
                        matches: matches,
                        startDate: selectedDate,
                        startTime: selectedTime,
                        daysCount: daysCount,
                        matchDurationMinutes: selectedMatchDuration,
                      );

                      if (success && context.mounted) {
                        onScheduleSaved();
                        VSPFeedback.showSuccess(
                          context,
                          isArabic
                              ? ' تم جدولة جميع مباريات $roundName تلقائياً بنجاح!'
                              : ' Auto-scheduled all $roundName matches successfully!',
                        );
                      } else if (!success && context.mounted) {
                        VSPFeedback.showError(
                            context, isArabic ? 'حدث خطأ أثناء الجدولة التلقائية' : 'Error auto-scheduling matches');
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
