import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/stadium_card.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';

/// شاشة ملاعبي - تظهر بعد تسجيل حساب المالك
/// حالتين: فارغة (أول مرة) أو ملاعب مسجلة
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
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
              child: Row(
                children: [
                  // Back button logic if needed (e.g. if pushed from somewhere else)
                  // For now, it's a main screen after auth, so maybe no back button or logout
                  const Spacer(),
                  Text(
                    'Stadiums',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const Spacer(),
                  // Hidden icon for balance
                  const SizedBox(width: 48), 
                ],
              ),
            ),

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
                        
                        // We check if data exists and is not empty
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

  // ===================== EMPTY STATE =====================
  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: VSPSpacing.xl),

        Text(
          'All your stadiums will appear here.',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: VSPSpacing.sm),

        Text(
          'Add your stadium now',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
          textAlign: TextAlign.center,
        ),

        // Stadium 3D Illustration
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: CachedNetworkImage(
                imageUrl: '', // Removed fake 3D illustration placeholder
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.stadium,
                  size: 120,
                  color: VSPColors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===================== STADIUMS LIST =====================
  Widget _buildStadiumsList(List<Stadium> stadiums) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
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

  // ===================== BOTTOM BUTTONS =====================
  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        children: [
          PrimaryButton(
            text: 'Add stadium',
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
            text: 'Complete your info',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OwnerDocumentationWizard()),
              );
            },
          ),
          const SizedBox(height: VSPSpacing.md),
        ],
      ),
    );
  }
}
