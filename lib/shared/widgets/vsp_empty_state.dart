import 'package:flutter/material.dart';
import '../../core/ui/vsp_ui.dart';
import 'primary_button.dart';

/// Canonical actionable empty state backed by Design System V2.
/// All empty-state surfaces share the same bounded, scroll-safe presentation.
class VSPEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const VSPEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? action = buttonText != null && onButtonPressed != null
        ? SizedBox(
            width: double.infinity,
            child: PrimaryButton(text: buttonText!, onPressed: onButtonPressed),
          )
        : null;

    return VSPStateView(
      state: VSPUiState.empty,
      icon: icon,
      title: title,
      message: subtitle,
      action: action,
    );
  }
}
