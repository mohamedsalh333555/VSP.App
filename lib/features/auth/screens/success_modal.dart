import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../owner/screens/facility_onboarding_screen.dart';
import '../../player/screens/player_home_screen.dart';

/// Show success modal dialog
void showSuccessModal(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: authProvider.isOwner
          ? const _OwnerSuccessModal()
          : const _PlayerSuccessModal(),
    ),
  );
}

/// Owner success modal content
class _OwnerSuccessModal extends StatelessWidget {
  const _OwnerSuccessModal();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success Icon with decorations
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Decorative elements
                Positioned(
                  top: 10,
                  left: 30,
                  child: _DecorativeShape(
                    color: AppTheme.neonGreen,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 30,
                  right: 40,
                  child: _DecorativeShape(
                    color: Colors.orange,
                    size: 15,
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: _DecorativeShape(
                    color: Colors.orange,
                    size: 12,
                  ),
                ),
                Positioned(
                  bottom: 30,
                  right: 30,
                  child: _DecorativeShape(
                    color: AppTheme.neonGreen,
                    size: 18,
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: _DecorativeShape(
                    color: Colors.yellow,
                    size: 10,
                  ),
                ),

                // Main check icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.neonGreen,
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.neonGreen,
                    size: 60,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Success Message
          const Text(
            'Your account was\nsuccessfully created!',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Subtitle
          const Text(
            'Add your stadium now',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Done Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FacilityOnboardingScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                foregroundColor: AppTheme.darkBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Player success modal content
class _PlayerSuccessModal extends StatelessWidget {
  const _PlayerSuccessModal();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success Icon with decorations
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Decorative elements
                Positioned(
                  top: 10,
                  left: 30,
                  child: _DecorativeShape(
                    color: AppTheme.neonGreen,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 30,
                  right: 40,
                  child: _DecorativeShape(
                    color: Colors.orange,
                    size: 15,
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: _DecorativeShape(
                    color: Colors.orange,
                    size: 12,
                  ),
                ),
                Positioned(
                  bottom: 30,
                  right: 30,
                  child: _DecorativeShape(
                    color: AppTheme.neonGreen,
                    size: 18,
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: _DecorativeShape(
                    color: Colors.yellow,
                    size: 10,
                  ),
                ),

                // Main check icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.neonGreen,
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.neonGreen,
                    size: 60,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Success Message
          const Text(
            'successfully created\nnew password !',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Done Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlayerHomeScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                foregroundColor: AppTheme.darkBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative shape worker
class _DecorativeShape extends StatelessWidget {
  final Color color;
  final double size;

  const _DecorativeShape({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
