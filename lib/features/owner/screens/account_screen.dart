import 'package:flutter/material.dart';
import 'owner_account_management_screen.dart';

/// Backward-compatible Wrapper delegating directly to OwnerAccountManagementScreen.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OwnerAccountManagementScreen();
  }
}
