import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../data/models.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';

class OwnerStadiumsScreen extends StatefulWidget {
  final bool isDevMode;
  
  const OwnerStadiumsScreen({
    super.key,
    this.isDevMode = false,
  });

  @override
  State<OwnerStadiumsScreen> createState() => _OwnerStadiumsScreenState();
}

class _OwnerStadiumsScreenState extends State<OwnerStadiumsScreen> {
  
  @override
  void initState() {
    super.initState();
    // Fetch stadiums for the current owner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<StadiumProvider>(context, listen: false)
          .listenToOwnerStadiums(auth.firebaseUser!.uid);
      } else if (widget.isDevMode) {
        // Fallback for dev mode shortcut if no live user
        Provider.of<StadiumProvider>(context, listen: false).fetchStadiums();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false, // Hide back button if it's main tab
        title: Consumer<StadiumProvider>(
          builder: (context, provider, _) {
            return provider.stadiums.isNotEmpty
                ? Text(
                    'Stadiums',
                    style: Theme.of(context).textTheme.displayLarge,
                  )
                : const SizedBox.shrink();
          },
        ),
        centerTitle: true,
      ),
      body: Consumer<StadiumProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Text(
                'Error: ${provider.errorMessage}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.error),
              ),
            );
          }

          if (provider.stadiums.isEmpty) {
            return _buildEmptyState();
          }

          return _buildStadiumsList(provider.stadiums);
        },
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3D Stadium Illustration
            Image.asset(
              'assets/images/empty_stadium.png',
              width: 280,
              height: 280,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if image not found
                return Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.lg),
                  ),
                  child: Icon(
                    Icons.stadium_outlined,
                    size: 120,
                    color: VSPColors.textSecondary.withValues(alpha: 0.3),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              'All your stadiums will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.sm),
            Text(
              'Add your stadium now',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStadiumsList(List<Stadium> stadiums) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: stadiums.length,
      itemBuilder: (context, index) {
        final stadium = stadiums[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildStadiumCard(stadium),
        );
      },
    );
  }

  Widget _buildStadiumCard(Stadium stadium) {
    return VSPCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: stadium.imageUrl.isNotEmpty 
                    ? stadium.imageUrl 
                    : '', // Removed fake Unsplash stadium fallback
                fit: BoxFit.cover,
                memCacheWidth: 800,
                placeholder: (context, url) => Container(color: VSPColors.surface),
                errorWidget: (context, url, err) => Container(
                  color: VSPColors.surface, 
                  child: const Center(child: Icon(Icons.stadium_outlined, color: VSPColors.textSecondary, size: 48)),
                ),
              ),
              // Content overlay
              Stack(
                children: [
                  // Top Left: Location Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(VSPRadius.xl),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: VSPColors.accent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            stadium.location,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Top Right: Edit Icon
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_outlined, color: VSPColors.accent, size: 18),
                    ),
                  ),

                  // Bottom Info Bar with Blur
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(VSPRadius.lg),
                          bottomRight: Radius.circular(VSPRadius.lg),
                        ),
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  stadium.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Seats ${stadium.seatsCapacity} person',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildFeatureIcon(Icons.bathroom),
                              const SizedBox(width: 12),
                              _buildFeatureIcon(Icons.male),
                              const SizedBox(width: 12),
                              _buildFeatureIcon(Icons.favorite_border),
                              const Spacer(),
                              Text(
                                stadium.location.split(',').first,
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: VSPColors.accent,
                              borderRadius: BorderRadius.circular(VSPRadius.sm),
                            ),
                            child: Text(
                              'Price ${stadium.pricePerHour.toStringAsFixed(0)} eg',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon) {
    return Icon(
      icon,
      color: VSPColors.textSecondary,
      size: 18,
    );
  }

  Widget _buildBottomButtons() {
    return Consumer<StadiumProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg, vertical: VSPSpacing.lg),
          decoration: BoxDecoration(
            color: VSPColors.background,
            border: Border(top: BorderSide(color: VSPColors.divider.withValues(alpha: 0.1))),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add Stadium Button (Always visible)
                PrimaryButton(
                  text: 'Add stadium',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddStadiumWizard(),
                      ),
                    );
                  },
                ),
                
                // Complete Info Button (Only when stadiums exist)
                if (provider.stadiums.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: 'Complete your info',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OwnerDocumentationWizard(),
                        ),
                      );
                    },
                    color: VSPColors.accent,
                    textColor: Colors.black,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
