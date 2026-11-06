import 'package:flutter/material.dart';
import '../tokens/vsp_tokens.dart';

/// Shared compact charcoal dropdown used across player and owner filters.
class VSPFilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;

  const VSPFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : items.first,
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(labelFor(item), overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VSPColors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w600)),
          )).toList(),
          onChanged: onChanged,
          dropdownColor: VSPColors.surface,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
            color: VSPColors.textSecondary, size: 18),
          style: const TextStyle(color: VSPColors.textPrimary,
            fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
