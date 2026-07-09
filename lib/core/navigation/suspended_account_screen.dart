import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../ui/tokens/vsp_tokens.dart';

class SuspendedAccountScreen extends StatelessWidget {
  const SuspendedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

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
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                ),
                child: Icon(LucideIcons.ban,
                  color: Colors.redAccent,
                  size: 56,
                ),
              ),
              const SizedBox(height: VSPSpacing.xl),
              Text(
                isAr ? 'تم تعليق الحساب' : 'Account Suspended',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: VSPSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                child: Text(
                  isAr
                      ? 'لقد تم إيقاف حسابك مؤقتاً بسبب مراجعة إدارية أو مخالفة سياسات المنصة. يرجى التواصل مع الدعم الفني لحل هذه المشكلة.'
                      : 'Your account has been temporarily suspended due to administrative review or violation of policies. Please contact support to resolve this issue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: VSPColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Launch WhatsApp or support contact link placeholder
                  },
                  icon: Icon(LucideIcons.headphones, color: VSPColors.background),
                  label: Text(
                    isAr ? 'التواصل مع الدعم' : 'Contact Support',
                    style: const TextStyle(
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
                child: Text(
                  isAr ? 'تسجيل الخروج' : 'Sign Out',
                  style: const TextStyle(
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