import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../services/signup_validation_service.dart';

/// Visual progress indicator for password strength.
class SignupPasswordStrengthBar extends StatelessWidget {
  final String password;

  const SignupPasswordStrengthBar({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final strength = SignupValidationService.calculatePasswordStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strength.label,
              style: TextStyle(
                color: strength.color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(strength.score * 100).toInt()}%',
              style: TextStyle(
                color: strength.color,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength.score,
          backgroundColor: VSPColors.surfaceAlt,
          valueColor: AlwaysStoppedAnimation<Color>(strength.color),
          borderRadius: BorderRadius.circular(VSPRadius.xs),
          minHeight: 4,
        ),
      ],
    );
  }
}
