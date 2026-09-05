import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import 'primary_button.dart';

/// Reusable Error State Widget that automatically distinguishes between
/// offline network issues and backend/server failures.
class VSPErrorState extends StatelessWidget {
  final String? customMessage;
  final VoidCallback onRetry;
  final String? retryButtonText;

  const VSPErrorState({
    super.key,
    this.customMessage,
    required this.onRetry,
    this.retryButtonText,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final isOnline = ConnectivityService.instance.isCurrentOnline;

    final String title = !isOnline
        ? (isArabic ? 'لا يوجد اتصال بالإنترنت' : 'No Internet Connection')
        : (isArabic ? 'تعذر تحميل البيانات' : 'Failed to Load Data');

    final String subtitle = !isOnline
        ? (isArabic
            ? 'يرجى التحقق من اتصالك بالواي فاي أو بيانات الهاتف ثم إعادة المحاولة.'
            : 'Please check your Wi-Fi or mobile data connection and try again.')
        : (customMessage ??
            (isArabic
                ? 'تعذر الوصول إلى الخادم في الوقت الحالي، يرجى المحاولة مرة أخرى.'
                : 'Could not connect to the server at this time. Please try again.'));

    final IconData icon = !isOnline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(VSPSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFEF4444),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.textSecondary,
                      height: 1.5,
                      fontSize: 13,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 46,
              child: PrimaryButton(
                text: retryButtonText ?? (isArabic ? 'إعادة المحاولة' : 'Try Again'),
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
