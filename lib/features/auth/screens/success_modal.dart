import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../../../core/navigation/root_screen.dart';

/// Show success modal dialog
void showSuccessModal(BuildContext context, {bool isOwner = false}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => _UnifiedSuccessDialog(isOwner: isOwner),
  );
}

class _UnifiedSuccessDialog extends StatefulWidget {
  final bool isOwner;
  const _UnifiedSuccessDialog({this.isOwner = false});

  @override
  State<_UnifiedSuccessDialog> createState() => _UnifiedSuccessDialogState();
}

class _UnifiedSuccessDialogState extends State<_UnifiedSuccessDialog> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.isOwner;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: VSPColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(
              color: VSPColors.divider,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Checkmark
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: VSPColors.accent,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: VSPColors.accent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Iconsax.tick_circle_copy,
                      color: VSPColors.accent,
                      size: 50,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Success!',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 16),

              // Dynamic Message
              Text(
                isOwner
                    ? 'Your account was successfully created!\nYou are owner now'
                    : 'Your account was successfully created!\nYou are player now',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Done Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Always navigate to RootScreen - it's the "Source of Truth"
                    // It will handle players vs owners onboarding state automatically
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RootScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: VSPColors.background, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Done',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

