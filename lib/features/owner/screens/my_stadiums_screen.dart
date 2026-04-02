import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/stadium_card.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';

class MyStadiumsScreen extends StatefulWidget {
  const MyStadiumsScreen({super.key});

  @override
  State<MyStadiumsScreen> createState() => _MyStadiumsScreenState();
}

class _MyStadiumsScreenState extends State<MyStadiumsScreen> {
  final StadiumRepository _databaseService = StadiumRepository();
  final String? _ownerId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.myStadiumsTab,
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: _ownerId == null
                  ? _buildEmptyState()
                  : StreamBuilder<List<Stadium>>(
                      stream: _databaseService.getOwnerStadiums(_ownerId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                        }
                        
                        final stadiums = snapshot.data ?? [];
                        
                        if (stadiums.isEmpty) {
                          return _buildEmptyState();
                        }

                        return _buildStadiumsList(stadiums);
                      },
                    ),
            ),

            // Bottom Buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return VSPEmptyState(
      icon: Icons.stadium_outlined,
      title: l10n.stadiumsEmptyTitle,
      subtitle: l10n.stadiumsEmptySubtitle,
    );
  }

  Widget _buildStadiumsList(List<Stadium> stadiums) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
      physics: const BouncingScrollPhysics(),
      itemCount: stadiums.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: VSPSpacing.md),
          child: StadiumCard(
            stadium: stadiums[index],
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddStadiumWizard(stadiumId: stadiums[index].id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 100),
      child: Column(
        children: [
          PrimaryButton(
            text: l10n.addStadiumLabel,
            color: VSPColors.accent.withValues(alpha: 0.1),
            textColor: VSPColors.accent,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddStadiumWizard()),
              );
            },
          ),
          const SizedBox(height: VSPSpacing.md),
          PrimaryButton(
            text: l10n.identityPendingVerification,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OwnerDocumentationWizard()),
              );
            },
          ),
        ],
      ),
    );
  }
}
