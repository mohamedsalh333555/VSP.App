import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../ui/tokens/vsp_tokens.dart';

class OfflineErrorScreen extends StatelessWidget {
  const OfflineErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(VSPSpacing.lg),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: VSPColors.borderLight),
                ),
                child: Icon(LucideIcons.wifiOff,
                  color: VSPColors.textSecondary,
                  size: 56,
                ),
              ),
              const SizedBox(height: VSPSpacing.xl),
              const Text(
                'Connection Problem',
                style: TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: VSPSpacing.sm),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                child: Text(
                  'Could not load your profile. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VSPColors.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: VSPSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: VSPColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    elevation: 0,
                  ),
                  onPressed: auth.isLoading ? null : () => auth.retryDataFetch(),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(VSPColors.background),
                          ),
                        )
                      : const Text(
                          'Retry Connection',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: VSPSpacing.md),
              TextButton(
                onPressed: () async {
                  await auth.signOut();
                },
                style: TextButton.styleFrom(
                  foregroundColor: VSPColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: VSPSpacing.sm, horizontal: VSPSpacing.lg),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
