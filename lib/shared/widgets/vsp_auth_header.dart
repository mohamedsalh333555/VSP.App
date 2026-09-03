import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'vsp_back_button.dart';

/// هيدر تنقل موحد لشاشات التسجيل والمصادقة لضمان ثبات موضع زر الرجوع والشعار بالبكسل
class VSPAuthHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showLogo;

  const VSPAuthHeader({
    super.key,
    this.onBack,
    this.trailing,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
      child: Row(
        children: [
          VSPBackButton(
            onTap: onBack ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/welcome');
                  }
                },
          ),
          const Spacer(),
          if (trailing != null)
            trailing!
          else if (showLogo)
            Image.asset(
              'assets/images/logo.png',
              height: 24,
              fit: BoxFit.contain,
            ),
        ],
      ),
    );
  }
}
