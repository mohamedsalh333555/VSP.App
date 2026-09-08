import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'tournament_round_schedule_calculator.dart';

/// Modal bottom sheet allowing owners to configure and apply automatic match scheduling for a round.
class TournamentAutoScheduleModalSheet extends StatefulWidget {
  final Championship championship;
  final int roundIndex;
  final List<TournamentMatch> matches;
  final String roundName;
  final VoidCallback onScheduleSaved;

  const TournamentAutoScheduleModalSheet({
    super.key,
    required this.championship,
    required this.roundIndex,
    required this.matches,
    required this.roundName,
    required this.onScheduleSaved,
  });

  /// Displays the auto schedule modal bottom sheet.
  static void show(
    BuildContext context, {
    required Championship championship,
    required int roundIndex,
    required List<TournamentMatch> matches,
    required String roundName,
    required VoidCallback onScheduleSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TournamentAutoScheduleModalSheet(
        championship: championship,
        roundIndex: roundIndex,
        matches: matches,
        roundName: roundName,
        onScheduleSaved: onScheduleSaved,
      ),
    );
  }

  @override
  State<TournamentAutoScheduleModalSheet> createState() => _TournamentAutoScheduleModalSheetState();
}

class _TournamentAutoScheduleModalSheetState extends State<TournamentAutoScheduleModalSheet> {
  int _daysCount = 1;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  late int _selectedMatchDuration;
  late final List<int> _durationOptions;
  late final List<int> _availableDaysOptions;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedMatchDuration = widget.championship.matchDuration;
    _durationOptions = TournamentRoundScheduleCalculator.calculateDurationOptions(widget.championship.matchDuration);
    _availableDaysOptions = TournamentRoundScheduleCalculator.calculateAvailableDaysOptions(widget.matches.length);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final summaryBullets = TournamentRoundScheduleCalculator.buildScheduleSummary(
      matchCount: widget.matches.length,
      daysCount: _daysCount,
      formattedStartTime: _selectedTime.format(context),
      matchDuration: _selectedMatchDuration,
      isArabic: isArabic,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
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
                  isArabic ? 'الجدولة التلقائية (${widget.roundName})' : 'Auto Schedule (${widget.roundName})',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: VSPColors.divider),
          const SizedBox(height: 14),

          // 1. Days Distribution Options
          Text(
            isArabic
                ? 'كيف تريد توزيع مباريات الدور (${widget.matches.length} مباراة)؟'
                : 'How to divide ${widget.matches.length} matches?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: _availableDaysOptions.map((d) {
              final isSelected = _daysCount == d;
              final mPerD = (widget.matches.length / d).ceil();

              String title = isArabic
                  ? (d == 1 ? 'يوم واحد' : (d == 2 ? 'يومان' : '4 أيام'))
                  : (d == 1 ? '1 Day' : '$d Days');
              String subtitle = isArabic ? '$mPerD مباريات/يوم' : '$mPerD matches/day';
              if (d == 1) subtitle = isArabic ? '$mPerD مباراة' : '$mPerD matches';

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _daysCount = d),
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
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (d != null) setState(() => _selectedDate = d);
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
                              DateFormat('yyyy-MM-dd').format(_selectedDate),
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
                        final t = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (t != null) setState(() => _selectedTime = t);
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
                              _selectedTime.format(context),
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
                  value: _selectedMatchDuration,
                  underline: const SizedBox(),
                  dropdownColor: VSPColors.surface,
                  style: const TextStyle(
                      color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                  items: _durationOptions.map((mins) {
                    return DropdownMenuItem<int>(
                      value: mins,
                      child: Text(
                        mins == widget.championship.matchDuration ? '$mins دقيقة (إعدادات البطولة)' : '$mins دقيقة',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedMatchDuration = v);
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
                for (final bullet in summaryBullets) ...[
                  Text(
                    bullet,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                ],
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
                Navigator.pop(context);
                final success = await TournamentRepository().autoScheduleRoundMatches(
                  championshipId: widget.championship.id,
                  roundIndex: widget.roundIndex,
                  matches: widget.matches,
                  startDate: _selectedDate,
                  startTime: _selectedTime,
                  daysCount: _daysCount,
                  matchDurationMinutes: _selectedMatchDuration,
                );

                if (success && context.mounted) {
                  widget.onScheduleSaved();
                  VSPFeedback.showSuccess(
                    context,
                    isArabic
                        ? ' تم جدولة جميع مباريات ${widget.roundName} تلقائياً بنجاح!'
                        : ' Auto-scheduled all ${widget.roundName} matches successfully!',
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
  }
}
