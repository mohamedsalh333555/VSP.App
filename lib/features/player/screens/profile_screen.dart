import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/ui/components/vsp_section_title.dart';
import 'profile_subscreens/my_team_screen.dart';
import 'profile_subscreens/payment_methods_screen.dart';
import 'profile_subscreens/notifications_screen.dart';
import 'profile_subscreens/privacy_policy_screen.dart';
import 'profile_subscreens/language_screen.dart';
import 'profile_subscreens/help_center_screen.dart';
import 'profile_subscreens/edit_profile_screen.dart';
import 'profile_subscreens/favorites_screen.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../admin/screens/admin_dashboard.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../../core/ui/components/vsp_menu_item.dart';
import '../../../shared/widgets/team_card_hero.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/utils/vsp_feedback.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey _teamCardKey = GlobalKey();
  bool _isSharing = false;
  bool _isDeleting = false;

  Future<void> _shareTeamCard(String teamName) async {
    setState(() => _isSharing = true);
    try {
      RenderRepaintBoundary boundary = _teamCardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // High resolution
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final xFile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'vsp_team_card.png');
      
      await Share.shareXFiles(
        [xFile], 
        text: AppLocalizations.of(context)!.shareTeamMessage(teamName),
      );
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, AppLocalizations.of(context)!.shareFailedError);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Null Safety Fix
    final String? userProfileUrl = auth.userModel?.profileImageUrl;
    final String userName = auth.userModel?.name ?? AppLocalizations.of(context)!.player;
    final String userPosition = auth.userModel?.position ?? "ST";

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context)!.profile,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Team Card Section (Viral Feature)
              FutureBuilder<Team?>(
                future: TeamRepository().getUserTeam(auth.currentUser!.uid),
                builder: (context, teamSnapshot) {
                  if (teamSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: VSPColors.accent),
                      ),
                    );
                  }

                  final team = teamSnapshot.data;

                  if (team != null) {
                    // HAS TEAM -> Show Shareable Card
                    return Column(
                      children: [
                        RepaintBoundary(
                          key: _teamCardKey,
                          child: TeamCardHero(team: team),
                        ),
                        const SizedBox(height: VSPSpacing.md),
                        PrimaryButton(
                          text: AppLocalizations.of(context)!.shareTeamCard,
                          icon: Icons.share_rounded,
                          color: VSPColors.accent.withValues(alpha: 0.15),
                          textColor: VSPColors.accent,
                          isLoading: _isSharing,
                          onPressed: () => _shareTeamCard(team.name),
                        ),
                      ],
                    );
                  } else {
                    // NO TEAM -> Show Free Agent Card
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.xl),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5), width: 2),
                      ),
                      padding: const EdgeInsets.all(VSPSpacing.xl),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: VSPColors.textSecondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(VSPRadius.sm),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.freeAgent,
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: VSPSpacing.md),
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: VSPColors.textSecondary, width: 2),
                              image: (userProfileUrl != null && userProfileUrl.isNotEmpty) 
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(userProfileUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            ),
                            child: (userProfileUrl == null || userProfileUrl.isEmpty)
                                ? const Icon(Icons.person, color: VSPColors.textSecondary, size: 40)
                                : null,
                          ),
                          const SizedBox(height: VSPSpacing.sm),
                          Text(
                            userName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            AppLocalizations.of(context)!.positionLabel(userPosition),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.accent),
                          ),
                          const SizedBox(height: VSPSpacing.lg),
                          Text(
                            AppLocalizations.of(context)!.freeAgentDescription,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.5),
                          ),
                          const SizedBox(height: VSPSpacing.lg),
                          PrimaryButton(
                            text: AppLocalizations.of(context)!.buildYourSquad,
                            height: 48,
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
                            },
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: VSPSpacing.xl),

              // 2. Account Section
              VSPSectionTitle(AppLocalizations.of(context)!.account),
              const SizedBox(height: VSPSpacing.sm),
              VSPFadeInItem(
                index: 0,
                child: VSPMenuItem(
                  icon: Icons.edit_outlined,
                  title: AppLocalizations.of(context)!.editProfile,
                  subtitle: AppLocalizations.of(context)!.editProfileSubtitle,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 1,
                child: VSPMenuItem(
                  icon: Icons.groups_outlined,
                  title: AppLocalizations.of(context)!.myTeam,
                  subtitle: AppLocalizations.of(context)!.manageTeamInfo,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 2,
                child: VSPMenuItem(
                  icon: Icons.favorite_border,
                  title: AppLocalizations.of(context)!.favoriteStadiums,
                  subtitle: AppLocalizations.of(context)!.viewLikedFacilities,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
                ),
              ),
              if (AppConfig.enableOnlinePayment) ...[
                VSPFadeInItem(
                  index: 3,
                  child: VSPMenuItem(
                    icon: Icons.payment_outlined,
                    title: AppLocalizations.of(context)!.paymentMethods,
                    subtitle: AppLocalizations.of(context)!.managePaymentMethods,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
                  ),
                ),
              ],

              const SizedBox(height: VSPSpacing.lg),

              // 3. Preferences Section
              VSPSectionTitle(AppLocalizations.of(context)!.preferences),
              const SizedBox(height: VSPSpacing.sm),
              VSPFadeInItem(
                index: 4,
                child: VSPMenuItem(
                  icon: Icons.notifications_none_outlined,
                  title: AppLocalizations.of(context)!.notifications,
                  subtitle: AppLocalizations.of(context)!.manageNotificationSettings,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 5,
                child: VSPMenuItem(
                  icon: Icons.shield_outlined,
                  title: AppLocalizations.of(context)!.privacy,
                  subtitle: AppLocalizations.of(context)!.privacyPolicy,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 6,
                child: VSPMenuItem(
                  icon: Icons.translate,
                  title: AppLocalizations.of(context)!.language,
                  subtitle: AppLocalizations.of(context)!.manageLanguagePreferences,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 7,
                child: VSPMenuItem(
                  icon: Icons.help_outline,
                  title: AppLocalizations.of(context)!.helpCenter,
                  subtitle: AppLocalizations.of(context)!.getHelpSupport,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
                ),
              ),

              const SizedBox(height: VSPSpacing.xl),

              // 4. Danger Zone (Logout & Delete Account)
              VSPFadeInItem(
                index: 8,
                child: VSPMenuItem(
                  icon: Icons.logout,
                  title: AppLocalizations.of(context)!.logout,
                  subtitle: AppLocalizations.of(context)!.signOutAccount,
                  isLogout: true,
                  onTap: () async {
                    await Provider.of<AuthProvider>(context, listen: false).signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
              
              // Bottom Padding to prevent nav bar overlap
              SizedBox(height: MediaQuery.of(context).padding.bottom + 110),
            ],
          ),
        ),
      ),
    );
  }
}
