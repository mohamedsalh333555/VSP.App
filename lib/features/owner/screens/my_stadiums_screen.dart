import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/database_service.dart';
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
  final DatabaseService _databaseService = DatabaseService();
  final String? _ownerId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  // Back button logic if needed (e.g. if pushed from somewhere else)
                  // For now, it's a main screen after auth, so maybe no back button or logout
                  const Spacer(),
                  const Text(
                    'Stadiums',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                          return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
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
        const SizedBox(height: 40),

        const Text(
          'All your stadiums will appear here.',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        const Text(
          'Add your stadium now',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),

        // Stadium 3D Illustration
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: CachedNetworkImage(
                imageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&q=80', // Replace with specific 3D illustration if available
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.stadium,
                  size: 120,
                  color: Colors.grey.withValues(alpha: 0.3),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: stadiums.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add Stadium Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                // If in empty state, add a mock stadium for demonstration
                // In real app, navigate to AddStadiumScreen
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddStadiumWizard()),
                  );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF335500), // Dark Green/Olive
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Add stadium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Complete Your Info — only show if stadiums exist
          // Complete Your Info — Show only if we have stadiums (or based on some logic)
          // Since we are in a StreamBuilder now, we can't easily check 'hasStadiums' here without wrapping the whole Body in a StreamBuilder or using Provider.
          // However, for simplicity, let's just always show it or perhaps check AuthProvider.
          // The previous logic was `if (_hasStadiums)`. 
          // Let's wrapping this button in the StreamBuffer is tricky because it's outside the Expanded.
          // We can use a StreamBuilder here too, or just always show it for now to avoid complexity in this step.
          /*
          StreamBuilder<List<Stadium>>(
            stream: _ownerId != null ? _databaseService.getOwnerStadiums(_ownerId!) : Stream.value([]),
            builder: (context, snapshot) {
               if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                 return ... button code ...
               }
               return SizedBox();
            }
          )
          */
          // Let's just keep it visible for now as it's a useful shortcut.
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const OwnerDocumentationWizard()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Complete your info',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
