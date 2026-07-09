import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../ui/tokens/vsp_tokens.dart';
import '../ui/components/vsp_card.dart';

class OfflineErrorScreen extends StatefulWidget {
  const OfflineErrorScreen({super.key});

  @override
  State<OfflineErrorScreen> createState() => _OfflineErrorScreenState();
}

class _OfflineErrorScreenState extends State<OfflineErrorScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Stack(
        children: [
          // ── Beautiful background glows for depth ──
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VSPColors.accent.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VSPColors.accent.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── Content ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0),
                  curve: Curves.easeOutBack,
                ),
                child: VSPCard(
                  isGlass: true,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Pulsing Offline Icon ──
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: VSPColors.accent.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: VSPColors.accent.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: VSPColors.accent.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: Icon(
                                LucideIcons.wifiOff,
                                color: VSPColors.accent,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // ── Title Localized ──
                      Text(
                        isAr ? 'الاتصال مفقود' : 'Connection Problem',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Description Localized ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          isAr 
                              ? 'تعذر تحميل ملفك الشخصي. يرجى التحقق من اتصالك بالإنترنت وإعادة المحاولة.'
                              : 'Could not load your profile. Please check your internet connection and try again.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: VSPColors.textSecondary,
                            height: 1.6,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Action Buttons ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.accent,
                            foregroundColor: VSPColors.background,
                            shadowColor: VSPColors.accent.withValues(alpha: 0.3),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                            ),
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
                              : Text(
                                  isAr ? 'إعادة المحاولة' : 'Retry',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          await auth.signOut();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: VSPColors.textSecondary.withValues(alpha: 0.8),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.sm),
                          ),
                        ),
                        child: Text(
                          isAr ? 'تسجيل الخروج' : 'Sign Out',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}