import 'package:flutter/material.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../champion_podium_components.dart';

class League1v1RegistrationActionCard extends StatelessWidget {
  final bool isRegistered; final int? myIndex; final bool isBrowsingDifferentGov;
  final String userGov; final dynamic tournamentGov; final String selectedLocation;
  final String status; final int remainingCount; final double entryFee;
  final bool isProcessingPayment; final bool isArabic;
  final VoidCallback onJoinPressed; final VoidCallback onSwitchToUserGov;

  const League1v1RegistrationActionCard({super.key, required this.isRegistered, required this.myIndex, required this.isBrowsingDifferentGov, required this.userGov, required this.tournamentGov, required this.selectedLocation, required this.status, required this.remainingCount, required this.entryFee, required this.isProcessingPayment, required this.isArabic, required this.onJoinPressed, required this.onSwitchToUserGov});

  @override
  Widget build(BuildContext context) {
    if (isRegistered) return _box(Icons.check_circle_outline, isArabic ? 'أنت مسجل في البطولة' : 'You are registered', isArabic ? 'تم تأكيد سداد الاشتراك.' : 'Your entry payment is confirmed.', VSPColors.success);
    if (isBrowsingDifferentGov) {
      final location = tournamentGov ?? selectedLocation;
      return _box(Icons.location_on_outlined,
        isArabic ? 'البطولة في ${championTranslateItem(context, location.toString())}' : 'Tournament in @@LOC',
        isArabic ? 'التسجيل متاح من محافظتك: $userGov.' : 'Registration is available from your home governorate: $userGov.',
        VSPColors.warning,
        action: OutlinedButton(onPressed: onSwitchToUserGov, style: OutlinedButton.styleFrom(foregroundColor: VSPColors.textPrimary, side: const BorderSide(color: VSPColors.divider), minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button))), child: Text(isArabic ? 'عرض محافظتي' : 'My governorate')));
    }
    final canJoin = status == 'registration_open' && remainingCount > 0 && entryFee > 0;
    if (canJoin) return PrimaryButton(
      text: isProcessingPayment ? (isArabic ? 'جاري فتح الدفع...' : 'Opening payment...') : (isArabic ? 'التسجيل • ${entryFee.toStringAsFixed(0)} ج.م' : 'Register • @@FEE EGP'),
      height: 50, color: VSPColors.accent, textColor: Colors.black, isLoading: isProcessingPayment, onPressed: onJoinPressed);
    final message = remainingCount <= 0 ? (isArabic ? 'اكتمل عدد اللاعبين.' : 'The tournament is full.') : status != 'registration_open' ? (isArabic ? 'التسجيل مغلق حاليًا.' : 'Registration is currently closed.') : (isArabic ? 'رسوم الاشتراك غير متاحة حاليًا.' : 'Entry fee is currently unavailable.');
    return _box(Icons.info_outline, message, isArabic ? 'يمكنك العودة لاحقًا.' : 'You can check again later.', VSPColors.textSecondary);
  }

  Widget _box(IconData icon, String title, String subtitle, Color iconColor, {Widget? action}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.card), border: Border.all(color: VSPColors.divider)),
    child: Row(children: [
      Icon(icon, color: iconColor, size: 21), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
      ])),
      if (action != null) ...[const SizedBox(width: 10), action],
    ]),
  );
}