import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

class MatchResultModal extends StatefulWidget {
  final Booking booking;
  final String submittingTeamId;
  final Function(MatchOutcome outcome, double? rating, String? review) onConfirm;

  const MatchResultModal({
    super.key, 
    required this.booking,
    required this.submittingTeamId,
    required this.onConfirm,
  });

  @override
  State<MatchResultModal> createState() => _MatchResultModalState();
}

class _MatchResultModalState extends State<MatchResultModal> {
  int _selectedIndex = -1; // -1: None, 0: We Won, 1: Draw, 2: We Lost
  double _rating = 0;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
        ),
        padding: const EdgeInsets.all(VSPSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'تأكيد نتيجة المباراة' : 'Confirm Match Result',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: VSPSpacing.xs),
                        Text(
                          isArabic ? 'يرجى تأكيد النتيجة النهائية للمباراة' : 'Please Confirm The Final Match Outcome',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: VSPColors.accent,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x, color: VSPColors.textPrimary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: VSPSpacing.lg),

              // Match Info Card
              Container(
                padding: const EdgeInsets.all(VSPSpacing.md),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                ),
                child: Column(
                  children: [
                    // Teams 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTeamDisplay(widget.booking.playerTeamName ?? (isArabic ? 'فريقك' : 'Your Team')),
                        Text(
                          'VS',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: VSPColors.accent,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                        _buildTeamDisplay(widget.booking.opponentTeamName ?? (isArabic ? 'المنافس' : 'Opponent')),
                      ],
                    ),
                    const SizedBox(height: VSPSpacing.lg),
                    const Divider(color: VSPColors.divider, height: 1),
                    const SizedBox(height: VSPSpacing.md),
                    // Details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem(isArabic ? 'التاريخ' : 'Date', widget.booking.formattedDate),
                        _buildDetailItem(isArabic ? 'الملعب' : 'Stadium', widget.booking.stadiumName),
                        _buildDetailItem(isArabic ? 'السعر' : 'Price', '${widget.booking.totalPrice.toInt()} ${widget.booking.currency}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Selection Options
              _buildSelectionOption(0, isArabic ? 'فزنا بالمباراة 🏆' : 'We Won', LucideIcons.trophy, VSPColors.warning),
              const SizedBox(height: 12),
              _buildSelectionOption(1, isArabic ? 'تعادل 🤝' : 'Draw', LucideIcons.repeat, const Color(0xFF3B82F6)),
              const SizedBox(height: 12),
              _buildSelectionOption(2, isArabic ? 'خسرنا المباراة' : 'We Lost', LucideIcons.frown, VSPColors.error),

              const SizedBox(height: VSPSpacing.lg),
              const Divider(color: VSPColors.divider),
              const SizedBox(height: VSPSpacing.lg),

              // Rating Section
              _buildRatingSection(isArabic),

              const SizedBox(height: 32),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: isArabic ? 'إلغاء' : 'Cancel',
                      height: 48,
                      color: VSPColors.surfaceAlt,
                      textColor: VSPColors.textPrimary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      text: isArabic ? 'إرسال النتيجة' : 'Submit Result',
                      height: 48,
                      onPressed: _selectedIndex == -1 ? null : _handleSubmit,
                      isLoading: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    late MatchOutcome outcome;

    final isHome = widget.submittingTeamId == widget.booking.playerTeamId;

    if (_selectedIndex == 0) { // We Won
      outcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
    } else if (_selectedIndex == 1) { // Draw
      outcome = MatchOutcome.draw;
    } else { // We Lost
      outcome = isHome ? MatchOutcome.awayWin : MatchOutcome.homeWin;
    }

    widget.onConfirm(
      outcome,
      _rating > 0 ? _rating : null,
      _reviewController.text.trim().isNotEmpty ? _reviewController.text.trim() : null,
    );
    
    // Trigger rating update logic (could be passed back via the callback in a future iteration,
    // but for now, we assume the callback handles the outcome and the provider handles the rating)
  }

  Widget _buildRatingSection(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'تقييم الملعب (اختياري)' : 'Rate the Stadium (Optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: VSPSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = index + 1.0;
                });
              },
              child: Icon(
                index < _rating ? LucideIcons.star : LucideIcons.star,
                color: VSPColors.warning,
                size: 32,
              ),
            );
          }),
        ),
        const SizedBox(height: VSPSpacing.md),
        TextField(
          controller: _reviewController,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: isArabic ? 'اكتب تقييمك وانطباعك...' : 'Write a review...',
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
            filled: true,
            fillColor: VSPColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionOption(int index, String label, IconData icon, Color activeColor) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isSelected ? activeColor : VSPColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : VSPColors.textSecondary),
            const SizedBox(width: VSPSpacing.md),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isSelected ? VSPColors.textPrimary : VSPColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(LucideIcons.checkCircle, color: activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDisplay(String name) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: VSPColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: VSPColors.divider),
          ),
          child: Icon(LucideIcons.trophy, color: VSPColors.textSecondary),
        ),
        const SizedBox(height: VSPSpacing.sm),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.textSecondary,
              ),
        ),
        const SizedBox(height: VSPSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}


