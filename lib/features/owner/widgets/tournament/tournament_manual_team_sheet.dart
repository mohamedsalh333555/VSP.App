import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Bottom sheet allowing tournament owners to manually register external teams and rosters.
void showTournamentManualTeamSheet(
  BuildContext context, {
  required Championship championship,
  required ValueChanged<Championship> onTeamAdded,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final nameCtrl = TextEditingController();
  final playerInputCtrl = TextEditingController();

  final List<Map<String, dynamic>> quickColors = [
    {'name': 'أبيض', 'value': '#FFFFFF', 'color': Colors.white},
    {'name': 'أحمر', 'value': '#EF4444', 'color': Colors.red},
    {'name': 'أزرق', 'value': '#3B82F6', 'color': Colors.blue},
    {'name': 'أخضر', 'value': '#22C55E', 'color': Colors.green},
    {'name': 'أصفر', 'value': '#F59E0B', 'color': Colors.amber},
    {'name': 'أسود', 'value': '#18181B', 'color': Colors.black},
  ];

  String selectedPrimaryColor = '#FFFFFF';
  List<String> offlinePlayerNames = [];
  bool isPaidOnCreation = true;
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(sheetContext).padding.bottom + MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        ),
        child: StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final teamName = nameCtrl.text.trim();
            final isNameValid = teamName.isNotEmpty;
            final totalPlayers = offlinePlayerNames.length;
            final bool isValidRoster = totalPlayers >= 5 && totalPlayers <= 12;
            final bool canSubmit = isNameValid && isValidRoster && !isSubmitting;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: VSPColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'إضافة فريق يدويًا' : 'Add Team Manually',
                      style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                Text(
                  isArabic
                      ? 'تسجيل وتنسيق فريق خارجي يدويًا في قائمة البطولة'
                      : 'Manually add and register an external team to the tournament',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Team Name
                        _buildSectionLabel(isArabic ? 'اسم الفريق:' : 'Team Name:'),
                        CustomTextField(
                          controller: nameCtrl,
                          hintText: isArabic ? 'اكتب اسم فريق' : 'Enter team name',
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        if (!isNameValid) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Iconsax.warning_2_copy, color: Colors.orange, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? ' يرجى كتابة اسم الفريق لتفعيل التنسيق' : ' Please enter team name',
                                style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // 2. Payment Status
                        _buildSectionLabel(isArabic ? 'حالة سداد رسوم الاشتراك:' : 'Payment Status:'),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => isPaidOnCreation = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isPaidOnCreation ? VSPColors.accent : VSPColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(VSPRadius.md),
                                    border: Border.all(color: isPaidOnCreation ? VSPColors.accent : VSPColors.divider),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: isPaidOnCreation ? Colors.black : VSPColors.accent, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        isArabic ? 'تم الدفع ' : 'Paid ',
                                        style: TextStyle(
                                          color: isPaidOnCreation ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => isPaidOnCreation = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !isPaidOnCreation
                                        ? VSPColors.warning.withValues(alpha: 0.2)
                                        : VSPColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(VSPRadius.md),
                                    border: Border.all(color: !isPaidOnCreation ? VSPColors.warning : VSPColors.divider),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.access_time_filled,
                                          color: !isPaidOnCreation ? VSPColors.warning : VSPColors.textSecondary,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        isArabic ? 'معلق / غير مدفوع ' : 'Pending ',
                                        style: TextStyle(
                                          color: !isPaidOnCreation ? VSPColors.warning : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. Shirt Color
                        _buildSectionLabel(isArabic ? 'لون قميص الفريق:' : 'Shirt Color:'),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: quickColors.length,
                            itemBuilder: (context, index) {
                              final item = quickColors[index];
                              final isSelected = selectedPrimaryColor == item['value'];
                              return GestureDetector(
                                onTap: () => setDialogState(() => selectedPrimaryColor = item['value']),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: item['color'],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? VSPColors.accent : VSPColors.divider,
                                      width: isSelected ? 3.0 : 1.0,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(Iconsax.tick_circle_copy,
                                          color: item['color'] == Colors.white ? Colors.black : Colors.white,
                                          size: 16)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 4. Roster List
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic ? 'كشف أسماء اللاعبين (من 5 إلى 12):' : 'Roster (5 to 12 players):',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                '$totalPlayers / 12',
                                style: TextStyle(
                                  color: isValidRoster ? VSPColors.accent : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: playerInputCtrl,
                                hintText: isArabic ? 'اكتب اسم اللاعب واضغط إضافة...' : 'Enter player name...',
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  final pName = playerInputCtrl.text.trim();
                                  if (pName.isEmpty) return;
                                  if (offlinePlayerNames.contains(pName)) return;
                                  if (offlinePlayerNames.length >= 12) return;

                                  setDialogState(() {
                                    offlinePlayerNames.add(pName);
                                    playerInputCtrl.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VSPColors.accent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                                ),
                                child: const Icon(Icons.add, size: 22),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (offlinePlayerNames.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: VSPColors.background,
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(color: VSPColors.divider),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: offlinePlayerNames.map((name) {
                                return Chip(
                                  backgroundColor: VSPColors.surfaceAlt,
                                  label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                  onDeleted: () {
                                    setDialogState(() {
                                      offlinePlayerNames.remove(name);
                                    });
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                                    side: const BorderSide(color: VSPColors.divider),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        if (totalPlayers < 5) ...[
                          const SizedBox(height: 8),
                          Text(
                            isArabic
                                ? ' يجب إضافة ${5 - totalPlayers} لاعبين إضافيين لتشغيل كشف الفريق'
                                : ' Add ${5 - totalPlayers} more players',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(sheetContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.surfaceAlt,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                          ),
                          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: PrimaryButton(
                          text: isArabic ? 'تأكيد إضافة الفريق' : 'Confirm Add Team',
                          color: canSubmit ? VSPColors.accent : VSPColors.surfaceAlt,
                          textColor: canSubmit ? Colors.black : VSPColors.textSecondary,
                          isLoading: isSubmitting,
                          onPressed: () async {
                            if (!isNameValid) {
                              VSPFeedback.showError(
                                  sheetContext, isArabic ? 'يرجى كتابة اسم الفريق أولاً' : 'Please enter team name first');
                              return;
                            }
                            if (!isValidRoster) {
                              VSPFeedback.showError(sheetContext,
                                  isArabic ? 'يرجى إضافة 5 لاعبين على الأقل لكشف الفريق' : 'Please add at least 5 players');
                              return;
                            }

                            final teamNameVal = nameCtrl.text.trim();
                            setDialogState(() => isSubmitting = true);

                            try {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final currentUserId = auth.currentUser?.uid ?? auth.currentUser?.id ?? '';

                              final teamId = await TeamRepository().createTeam({
                                'name': teamNameVal,
                                'captainName': isArabic ? 'تسجيل يدوي' : 'Manual Registration',
                                'captainImageUrl': '',
                                'logoUrl': '',
                                'sportType': championship.sportType,
                                'governorate': championship.governorate,
                                'memberUids': [
                                  currentUserId.isNotEmpty ? currentUserId : '8d3d7d65-a167-4138-b36c-85bbdead1b7a'
                                ],
                                'date': 'Upcoming',
                                'primary_color': selectedPrimaryColor,
                                'secondary_color': '#000000',
                              });

                              if (teamId != null) {
                                await TournamentRepository().joinChampionship(
                                  championship.id,
                                  teamId,
                                  skipMemberCheck: true,
                                  isPaid: isPaidOnCreation,
                                );
                                await TournamentRepository().insertChampionshipRoster(
                                  championshipId: championship.id,
                                  teamId: teamId,
                                  guestNames: offlinePlayerNames,
                                );

                                final updatedChampionship = championship.copyWith(
                                  joinedTeams: [...championship.joinedTeams, teamId],
                                  paidTeams: isPaidOnCreation
                                      ? [...championship.paidTeams, teamId]
                                      : championship.paidTeams,
                                );

                                onTeamAdded(updatedChampionship);

                                if (context.mounted) {
                                  Navigator.pop(sheetContext);
                                  VSPFeedback.showSuccess(
                                    context,
                                    isArabic
                                        ? 'تم إضافة الفريق للبطولة بنجاح.'
                                        : 'Team added to tournament successfully.',
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                              if (context.mounted) {
                                VSPFeedback.showError(context, e.toString());
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    nameCtrl.dispose();
    playerInputCtrl.dispose();
  });
}

Widget _buildSectionLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(
      label,
      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}
