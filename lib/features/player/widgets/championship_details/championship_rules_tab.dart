import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// تبويب قواعد وتعليمات البطولة وآلية تسليم الجوائز
class ChampionshipRulesTab extends StatelessWidget {
  final Championship championship;

  const ChampionshipRulesTab({super.key, required this.championship});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            isArabic ? 'وصف عن البطولة' : 'About Tournament',
            championship.rules.isNotEmpty
                ? championship.rules
                : (isArabic
                    ? 'بطولة رسمية تنافسية لفرق كرة القدم بمدينة ${championship.governorate.isNotEmpty ? championship.governorate : "مصر"}.'
                    : 'Official competitive football tournament.'),
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            isArabic ? 'آلية تسليم الجوائز المالية' : 'Prize Handover & Distribution',
            isArabic
                ? '• تُسلم الجوائز والمكافآت المالية للفرق الفائزة بالمركز الأول والوصيف فور انتهاء المباراة النهائية مباشرة.\n• التسليم يتم نقداً بالملعب أو عبر تحويل فوري معتمد (InstaPay / المحفظة الإلكترونية) بمعرفة إدارة الملعب والمنظم.'
                : '• Monetary prizes are awarded to the Champion and Runner-up immediately post-final match.\n• Prizes are handed on-pitch in cash or via instant verified InstaPay / E-Wallet transfer by stadium organizers.',
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            isArabic ? 'قوانين المباريات' : 'Match Rules',
            isArabic
                ? '• مدة المباراة: ${championship.matchDuration > 0 ? "${championship.matchDuration} دقيقة" : "غير محددة"}.\n'
                    '• عدد اللاعبين الأساسيين لكل فريق: ${championship.minPlayersPerTeam} لاعبين.\n'
                    '• الحد الأقصى للاعبين في التشكيلة: ${championship.maxPlayersPerTeam} لاعبين.\n'
                    '• احتساب النقاط: ${championship.winningPoints} نقاط للفوز، ${championship.drawPoints} نقطة للتعادل، ${championship.lossPoints} للهزيمة.'
                : '• Match Duration: ${championship.matchDuration > 0 ? "${championship.matchDuration} mins" : "TBD"}.\n'
                    '• Min Players: ${championship.minPlayersPerTeam}.\n'
                    '• Max Players: ${championship.maxPlayersPerTeam}.\n'
                    '• Points: ${championship.winningPoints} Win / ${championship.drawPoints} Draw / ${championship.lossPoints} Loss.',
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            isArabic ? 'تعليمات وإرشادات مهمة' : 'Important Instructions',
            isArabic
                ? '• يرجى التواجد بالملعب قبل موعد المباراة بـ 15 دقيقة على الأقل.\n'
                    '• يجب التزام جميع الفرق بالزي الرياضي الموحد.\n'
                    '• أي بطاقة حمراء تؤدي لإيقاف اللاعب المباراة التالية.'
                : '• Please arrive 15 minutes prior to kickoff.\n'
                    '• Unified sports gear is required.\n'
                    '• Red card suspends player for next match.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}
