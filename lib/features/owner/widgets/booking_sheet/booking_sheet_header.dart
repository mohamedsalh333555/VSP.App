import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Top grab handle and header row with dynamic title and optional delete button for owner booking sheet.
class BookingSheetHeader extends StatelessWidget {
  final String title;
  final bool showDeleteButton;
  final bool isDeleting;
  final VoidCallback? onDelete;

  const BookingSheetHeader({
    super.key,
    required this.title,
    required this.showDeleteButton,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VSPColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.displaySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showDeleteButton)
              IconButton(
                icon: const Icon(Iconsax.trash_copy, color: VSPColors.error),
                onPressed: isDeleting ? null : onDelete,
              ),
          ],
        ),
      ],
    );
  }
}
