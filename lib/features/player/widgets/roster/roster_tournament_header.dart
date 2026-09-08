import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/vsp_countdown_timer.dart';

/// Header card displaying team & championship names, editing permission status, and countdown to kick-off.
class RosterTournamentHeader extends StatelessWidget {
  final String teamName;
  final String championshipName;
  final DateTime startDate;
  final bool canEdit;
  final bool isArabic;

  const RosterTournamentHeader({
    super.key,
    required this.teamName,
    required this.championshipName,
    required this.startDate,
    required this.canEdit,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: canEdit
              ? VSPColors.accent.withValues(alpha: 0.3)
              : VSPColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.people_copy,
                  color: VSPColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      championshipName,
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: canEdit
                      ? VSPColors.success.withValues(alpha: 0.15)
                      : VSPColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                child: Text(
                  canEdit
                      ? (isArabic ? 'مفتوح للتعديل' : 'Editable')
                      : (isArabic ? 'مغلق رسمياً ' : 'Locked '),
                  style: TextStyle(
                    color: canEdit ? VSPColors.success : VSPColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 12),
            VSPCountdownTimer(targetDate: startDate),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VSPColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle_copy, color: VSPColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'تم إغلاق تعديل التشكيلة لبدء فعاليات البطولة.'
                          : 'Roster editing is locked as tournament started.',
                      style: const TextStyle(
                        color: VSPColors.error,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
