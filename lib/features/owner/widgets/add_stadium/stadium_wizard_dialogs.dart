import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart' as app_auth;
import '../../../../core/repositories/stadium_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

class StadiumWizardDialogs {
  static Future<bool> showDiscardConfirmation(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isArabic ? 'تجاهل التغييرات؟ ⚠️' : 'Discard changes? ⚠️',
          style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? 'لديك بيانات وتعديلات غير محفوظة، هل أنت متأكد من الخروج؟'
              : 'You have unsaved data. Are you sure you want to exit?',
          style: const TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isArabic ? 'خروج' : 'Exit', style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  static Future<void> showDeleteStadiumDialog(
    BuildContext context, {
    required String stadiumId,
    required VoidCallback onDeleted,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isArabic ? 'إخفاء وحذف الملعب؟ ⚠️' : 'Hide & Delete Stadium? ⚠️',
          style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في إخفاء هذا الملعب؟ سيتم إيقافه وإخفاؤه فوراً عن اللاعبين ولن تظهر حجوزاته، ولن يتم الحذف النهائي من قاعدة البيانات إلا بعد تواصل الإدارة معك لمراجعة السبب والتأكيد.'
              : 'Are you sure you want to hide this stadium? It will be immediately hidden from players. Permanent deletion will only occur after admin contacts you to confirm.',
          style: const TextStyle(color: VSPColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
            ),
            child: Text(isArabic ? 'تأكيد الإخفاء' : 'Confirm Hide'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        bool success = false;
        try {
          success = await StadiumRepository().deleteStadium(stadiumId);
        } catch (e) {
          if (e.toString().contains('active_bookings_exist')) {
            if (!context.mounted) return;
            VSPFeedback.showError(
              context,
              isArabic
                  ? 'لا يمكن حذف الملعب لوجود حجوزات نشطة اليوم أو في المستقبل! قم بإلغائها أو انتظار انتهائها أولاً.'
                  : 'Cannot delete stadium with active bookings today or in the future! Cancel them or wait for completion first.',
            );
            return;
          }
        }

        if (!context.mounted) return;
        if (success) {
          final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
          final uid = auth.currentUser?.uid;
          if (uid != null) {
            final bool stillHas = await StadiumRepository().checkOwnerHasRemainingStadiums(uid);
            await auth.updateProfile({'hasStadium': stillHas});
          }

          if (context.mounted) {
            VSPFeedback.showSuccess(
              context,
              isArabic
                  ? 'تم حذف الملعب نهائياً واختفاؤه من التطبيق بنجاح! 🗑️'
                  : 'Stadium deleted permanently and hidden from app! 🗑️',
            );
            onDeleted();
          }
        } else {
          if (context.mounted) {
            VSPFeedback.showError(
              context,
              isArabic ? 'حدث خطأ أثناء عملية حذف الملعب' : 'Error deleting stadium',
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          VSPFeedback.showError(
            context,
            isArabic ? 'حدث خطأ أثناء عملية حذف الملعب' : 'Error deleting stadium',
          );
        }
      }
    }
  }
}
