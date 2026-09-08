import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Styled text label for form sections in the owner booking sheet.
class InputLabel extends StatelessWidget {
  final String label;

  const InputLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: VSPColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// Custom pill-shaped text input field styled for dark theme with LTR support.
class PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  const PillTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNumberOrPhone = keyboardType == TextInputType.phone ||
        keyboardType == TextInputType.number ||
        (keyboardType != null && keyboardType.toString().contains('number'));

    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 1),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textDirection: isNumberOrPhone ? TextDirection.ltr : null,
        inputFormatters: inputFormatters,
        style: TextStyle(
          color: enabled ? Colors.white : VSPColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

/// Counter widget for attending players in a booking.
class PlayerCounterField extends StatelessWidget {
  final int playerCount;
  final int maxPlayers;
  final bool isReadOnly;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const PlayerCounterField({
    super.key,
    required this.playerCount,
    required this.maxPlayers,
    required this.isReadOnly,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Iconsax.user_tag_copy, color: VSPColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                isArabic ? "إجمالي اللاعبين:" : "Total Players:",
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Iconsax.minus_cirlce_copy, size: 20, color: VSPColors.textPrimary),
                onPressed: (isReadOnly || playerCount <= 1) ? null : onDecrement,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$playerCount',
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.add_circle_copy, size: 20, color: VSPColors.textPrimary),
                onPressed: (isReadOnly || playerCount >= maxPlayers) ? null : onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
