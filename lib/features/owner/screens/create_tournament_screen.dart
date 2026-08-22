import 'package:flutter/material.dart';
import 'create_tournament_wizard.dart';

/// Legacy Wrapper: Forwarding directly to the active CreateTournamentWizard
class CreateTournamentScreen extends StatelessWidget {
  const CreateTournamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateTournamentWizard();
  }
}
