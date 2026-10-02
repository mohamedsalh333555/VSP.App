import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/ui/vsp_ui.dart';
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

    final title = !isOnline
        ? (isArabic ? 'لا يوجد اتصال بالإنترنت' : 'No Internet Connection')
        : (isArabic ? 'تعذر تحميل البيانات' : 'Could not load data');

    final message = !isOnline
        ? (isArabic
            ? 'تحقق من الاتصال ثم جرّب مرة أخرى.'
            : 'Check your connection and try again.')
        : (customMessage ??
            (isArabic
                ? 'تعذر الوصول إلى الخادم في الوقت الحالي.'
                : 'The server could not be reached right now.'));

    return VSPStateView(
      state: !isOnline ? VSPUiState.offline : VSPUiState.error,
      title: title,
      message: message,
      icon: !isOnline ? Iconsax.wifi_square_copy : Iconsax.cloud_cross_copy,
      onRetry: onRetry,
      action: retryButtonText != null
          ? PrimaryButton(
              text: retryButtonText!,
              onPressed: onRetry,
            )
          : null,
    );
  }
}
