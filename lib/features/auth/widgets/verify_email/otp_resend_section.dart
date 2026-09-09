import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Section providing OTP resend countdown button and option to change email/sign out.
class OtpResendSection extends StatelessWidget {
  final int countdown;
  final bool isResending;
  final bool isAr;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;

  const OtpResendSection({
    super.key,
    required this.countdown,
    required this.isResending,
    required this.isAr,
    required this.onResend,
    required this.onChangeEmail,
  });

  @override
  Widget build(BuildContext context) {
    final canResend = countdown == 0 && !isResending;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isAr ? 'لم يصلك الرمز؟ ' : "Didn't receive it? ",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VSPColors.textSecondary,
                  ),
            ),
            GestureDetector(
              onTap: canResend ? onResend : null,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: canResend ? VSPColors.accent : VSPColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                child: isResending
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: VSPColors.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(isAr ? 'جاري الإرسال...' : 'Sending...'),
                        ],
                      )
                    : Text(
                        canResend
                            ? (isAr ? 'إعادة إرسال الرمز' : 'Resend Code')
                            : (isAr ? 'إعادة إرسال خلال $countdown ثانية' : 'Resend in ${countdown}s'),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: onChangeEmail,
          child: Text(
            isAr
                ? 'أدخلت البريد بالخطأ؟ تغيير البريد وتسجيل الخروج'
                : 'Wrong email? Change email and sign out',
            style: const TextStyle(
              color: VSPColors.error,
              decoration: TextDecoration.underline,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
