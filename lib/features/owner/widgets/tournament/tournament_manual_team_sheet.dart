import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'tournament_manual_team_options_section.dart';
import 'tournament_manual_team_roster_section.dart';
import 'tournament_manual_team_service.dart';

/// Bottom sheet allowing tournament owners to manually register external teams and rosters.
void showTournamentManualTeamSheet(
  BuildContext context, {
  required Championship championship,
  required ValueChanged<Championship> onTeamAdded,
  TournamentManualTeamService? service,
}) {
  final manualTeamService = service ?? TournamentManualTeamService();
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final nameCtrl = TextEditingController();
  final playerInputCtrl = TextEditingController();

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
          MediaQuery.of(sheetContext).padding.bottom +
              MediaQuery.of(sheetContext).viewInsets.bottom +
              16,
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
                              const Icon(Iconsax.info_circle_copy, color: VSPColors.textSecondary, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                isArabic
                                    ? ' يرجى كتابة اسم الفريق لتفعيل التنسيق'
                                    : ' Please enter team name',
                                style: const TextStyle(
                                  color: VSPColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // 2 & 3. Options Section (Payment Status + Shirt Color)
                        TournamentManualTeamOptionsSection(
                          isPaidOnCreation: isPaidOnCreation,
                          onPaymentStatusChanged: (val) =>
                              setDialogState(() => isPaidOnCreation = val),
                          selectedPrimaryColor: selectedPrimaryColor,
                          onColorSelected: (val) =>
                              setDialogState(() => selectedPrimaryColor = val),
                        ),
                        const SizedBox(height: 20),

                        // 4. Roster Section
                        TournamentManualTeamRosterSection(
                          playerInputCtrl: playerInputCtrl,
                          offlinePlayerNames: offlinePlayerNames,
                          onChanged: () => setDialogState(() {}),
                          onAddPlayer: () {
                            final pName = playerInputCtrl.text.trim();
                            if (pName.isEmpty) return;
                            if (offlinePlayerNames.contains(pName)) return;
                            if (offlinePlayerNames.length >= 12) return;

                            setDialogState(() {
                              offlinePlayerNames.add(pName);
                              playerInputCtrl.clear();
                            });
                          },
                          onRemovePlayer: (name) {
                            setDialogState(() {
                              offlinePlayerNames.remove(name);
                            });
                          },
                        ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                            ),
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
                          onPressed: !canSubmit
                              ? null
                              : () async {
                                  if (!isNameValid) {
                                    VSPFeedback.showError(
                                      sheetContext,
                                      isArabic
                                          ? 'يرجى كتابة اسم الفريق أولاً'
                                          : 'Please enter team name first',
                                    );
                                    return;
                                  }
                                  if (!isValidRoster) {
                                    VSPFeedback.showError(
                                      sheetContext,
                                      isArabic
                                          ? 'يرجى إضافة 5 لاعبين على الأقل لكشف الفريق'
                                          : 'Please add at least 5 players',
                                    );
                                    return;
                                  }

                                  final teamNameVal = nameCtrl.text.trim();
                                  setDialogState(() => isSubmitting = true);

                                  try {
                                    final auth = Provider.of<AuthProvider>(context, listen: false);
                                    final currentUserId =
                                        auth.currentUser?.uid ?? auth.currentUser?.id;

                                    if (currentUserId == null || currentUserId.isEmpty) {
                                      VSPFeedback.showError(
                                        sheetContext,
                                        isArabic ? 'خطأ في التحقق من الهوية' : 'Authentication error',
                                      );
                                      setDialogState(() => isSubmitting = false);
                                      return;
                                    }

                                    final updatedChampionship =
                                        await manualTeamService.registerManualTeam(
                                      championship: championship,
                                      teamName: teamNameVal,
                                      currentUserId: currentUserId,
                                primaryColor: selectedPrimaryColor,
                                isPaid: isPaidOnCreation,
                                playerNames: offlinePlayerNames,
                                isArabic: isArabic,
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
      style: const TextStyle(
        color: VSPColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
