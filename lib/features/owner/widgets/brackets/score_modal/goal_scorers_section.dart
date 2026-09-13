import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../data/models.dart';

class GoalScorersList extends StatelessWidget {
  final String teamName;
  final List<GoalItem> goals;
  final ValueChanged<GoalItem> onRemoveGoal;

  const GoalScorersList({
    super.key,
    required this.teamName,
    required this.goals,
    required this.onRemoveGoal,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.element_4_copy, color: VSPColors.accent, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isArabic ? 'هدافو $teamName' : '$teamName Scorers',
                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            Text(
              isArabic ? 'لم يتم تسجيل أهداف بعد' : 'No goals recorded',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: goals.map((g) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        g.playerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onRemoveGoal(g),
                        child: const Icon(Iconsax.close_circle_copy, color: Colors.white54, size: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

void openAddGoalModal(
  BuildContext context, {
  required String teamId,
  required String teamName,
  required List<String> roster,
  required ValueChanged<GoalItem> onGoalAdded,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final TextEditingController customNameController = TextEditingController();
  String? selectedFromRoster;

  showDialog(
    context: context,
    builder: (dlgCtx) {
      return StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: VSPColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
            title: Row(
              children: [
                const Icon(Iconsax.element_4_copy, color: VSPColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'تسجيل هدف لـ $teamName ' : 'Record Goal for $teamName ',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roster.isNotEmpty) ...[
                    Text(
                      isArabic ? 'اختر اسم الهداف من كشف اللاعبين:' : 'Select scorer from roster:',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: VSPColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: DropdownButton<String>(
                        value: selectedFromRoster,
                        isExpanded: true,
                        hint: Text(
                          isArabic ? 'اختر لاعباً...' : 'Select a player...',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        dropdownColor: VSPColors.surface,
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: roster.map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDlgState(() {
                            selectedFromRoster = val;
                            if (val != null) customNameController.text = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        isArabic ? 'أو' : 'OR',
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    isArabic ? 'ادخل اسم الهداف يدوياً (للقوائم اليدوية):' : 'Enter scorer name manually:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'مثال: أحمد حسام / لاعب 1' : 'e.g. Ahmed / Player 1',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: VSPColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        borderSide: const BorderSide(color: VSPColors.divider),
                      ),
                    ),
                    onChanged: (val) {
                      if (selectedFromRoster != null && val != selectedFromRoster) {
                        setDlgState(() => selectedFromRoster = null);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final finalName = customNameController.text.trim().isNotEmpty
                      ? customNameController.text.trim()
                      : (selectedFromRoster ?? (isArabic ? 'لاعب مجهول' : 'Unknown Player'));

                  onGoalAdded(GoalItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    teamId: teamId,
                    playerName: finalName,
                    isOwnGoal: false,
                  ));
                  Navigator.pop(dlgCtx);
                },
                child: Text(
                  isArabic ? 'حفظ الهدف ' : 'Save Goal ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    customNameController.dispose();
  });
}
