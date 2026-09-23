import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../champion_podium_components.dart';

/// Interactive registration action card handling:
/// 1. Already registered confirmation box with seat index.
/// 2. Warning box if browsing outside the player's home governorate with switch button.
/// 3. Secure Paymob entry fee payment CTA button.
/// 4. Closed / Full capacity notice.
class League1v1RegistrationActionCard extends StatelessWidget {
  final bool isRegistered;
  final int? myIndex;
  final bool isBrowsingDifferentGov;
  final String userGov;
  final dynamic tournamentGov;
  final String selectedLocation;
  final String status;
  final int remainingCount;
  final double entryFee;
  final bool isProcessingPayment;
  final bool isArabic;
  final VoidCallback onJoinPressed;
  final VoidCallback onSwitchToUserGov;

  const League1v1RegistrationActionCard({
    super.key,
    required this.isRegistered,
    required this.myIndex,
    required this.isBrowsingDifferentGov,
    required this.userGov,
    required this.tournamentGov,
    required this.selectedLocation,
    required this.status,
    required this.remainingCount,
    required this.entryFee,
    required this.isProcessingPayment,
    required this.isArabic,
    required this.onJoinPressed,
    required this.onSwitchToUserGov,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: isRegistered
          ? _buildRegisteredState()
          : isBrowsingDifferentGov
              ? _buildDifferentGovState(context)
              : _buildJoinButtonOrClosedState(),
    );
  }

  Widget _buildRegisteredState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.tick_circle_copy, color: VSPColors.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'أنت مسجل في البطولة بنجاح!' : 'You are registered!',
                  style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'رقم مقعدك في الجدول: #$myIndex (تم سداد الاشتراك)'
                      : 'Your seat number: #$myIndex (Entry fee paid)',
                  style: TextStyle(color: VSPColors.success.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferentGovState(BuildContext context) {
    final tourneyLocation = tournamentGov ?? selectedLocation;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Iconsax.info_circle_copy, color: VSPColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'أنت تتصفح بطولة خارج محافظتك (${championTranslateItem(context, tourneyLocation.toString())}). الاشتراك متاح فقط في بطولات محافظتك ($userGov).'
                      : 'Viewing tournament in ${championTranslateItem(context, tourneyLocation.toString())}. Registration is available only in your home city ($userGov).',
                  style: const TextStyle(
                    color: VSPColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onSwitchToUserGov,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: VSPColors.warning),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.input)),
              ),
              icon: const Icon(Iconsax.location_copy, size: 16, color: VSPColors.warning),
              label: Text(
                isArabic
                    ? 'الانتقال إلى بطولات محافظتي ($userGov)'
                    : 'Switch to My City ($userGov)',
                style: const TextStyle(
                  color: VSPColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButtonOrClosedState() {
    if (status == 'registration_open' && remainingCount > 0) {
      return PrimaryButton(
        text: isProcessingPayment
            ? (isArabic ? 'جاري فتح بوابة الدفع...' : 'Opening payment...')
            : (isArabic
                ? 'سداد الاشتراك والانضمام (${entryFee.toStringAsFixed(0)} ج.م)'
                : 'Pay & Join (${entryFee.toStringAsFixed(0)} EGP)'),
        height: 50,
        color: VSPColors.accent,
        textColor: Colors.black,
        onPressed: isProcessingPayment ? () {} : onJoinPressed,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Text(
        isArabic ? 'اكتمل العدد أو تم إغلاق باب التسجيل' : 'Registration is closed or full',
        style: const TextStyle(
          color: VSPColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
