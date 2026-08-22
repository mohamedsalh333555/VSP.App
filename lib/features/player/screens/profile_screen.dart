import 'package:iconsax_flutter/iconsax_flutter.dart';
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
import 'terms_and_privacy_screen.dart';
import 'faq_and_support_screen.dart';
import 'profile_subscreens/language_screen.dart';
import 'profile_subscreens/edit_profile_screen.dart';
import 'profile_subscreens/favorites_screen.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/ui/components/vsp_menu_item.dart';
import '../../../shared/widgets/team_card_hero.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/providers/stadium_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey _teamCardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareTeamCard(String teamName) async {
    setState(() => _isSharing = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      RenderRepaintBoundary boundary = _teamCardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); 
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final xFile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'vsp_team_card.png');
      
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: l10n.shareTeamMessage(teamName),
        ),
      );
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, l10n.shareFailedError);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showLocationPicker(BuildContext context, AuthProvider auth) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    const governorates = EgyptGovernorates.allGovernorates;
    final currentGov = auth.userModel?.governorate ?? 'Aswan';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'تحديد المحافظة والموقع 📍' : 'Select Location / Governorate 📍',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic ? 'اختر محافظتك لعرض الملاعب والبطولات المتاحة:' : 'Choose your governorate to display available stadiums & tournaments:',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: governorates.length,
                  itemBuilder: (context, index) {
                    final gov = governorates[index];
                    final String displayGovName = isArabic 
                        ? (gov == 'Aswan' ? 'أسوان' : (gov == 'Cairo' ? 'القاهرة' : gov))
                        : gov;
                    final isSelected = currentGov == gov || currentGov == displayGovName;

                    return ListTile(
                      leading: Icon(
                        Iconsax.location_copy,
                        color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                      ),
                      title: Text(
                        displayGovName,
                        style: TextStyle(
                          color: isSelected ? VSPColors.accent : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent) : null,
                      onTap: () async {
                        await auth.updateProfile({'governorate': gov});
                        if (context.mounted) {
                          context.read<StadiumProvider>().applyGovernorateFilter(gov);
                          Navigator.pop(sheetContext);
                          VSPFeedback.showSuccess(
                            context,
                            isArabic ? 'تم تغيير موقعك إلى $displayGovName بنجاح 📍' : 'Location changed to $gov successfully 📍',
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = context.watch<AuthProvider>();
    final String? userProfileUrl = auth.userModel?.profileImageUrl;
    final String userName = auth.userModel?.name ?? l10n.player;
    final String userPosition = auth.userModel?.position ?? "ST";

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          l10n.profile,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Team Card Section
              FutureBuilder<Team?>(
                future: auth.currentUser == null
                    ? Future.value(null)
                    : TeamRepository().getUserTeam(auth.currentUser!.uid),
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
                    return Column(
                      children: [
                        RepaintBoundary(
                          key: _teamCardKey,
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
                              if (mounted) setState(() {});
                            },
                            child: TeamCardHero(team: team),
                          ),
                        ),
                        const SizedBox(height: VSPSpacing.md),
                        PrimaryButton(
                          text: l10n.shareTeamCard,
                          icon: Iconsax.share_copy,
                          color: VSPColors.accent.withValues(alpha: 0.15),
                          textColor: VSPColors.accent,
                          isLoading: _isSharing,
                          onPressed: () => _shareTeamCard(team.name),
                        ),
                      ],
                    );
                  } else {
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
                              l10n.freeAgent,
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
                                ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 40)
                                : null,
                          ),
                          const SizedBox(height: VSPSpacing.sm),
                          Text(
                            userName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l10n.positionLabel(userPosition),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.accent),
                          ),
                          const SizedBox(height: VSPSpacing.lg),
                          Text(
                            l10n.freeAgentDescription,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.5),
                          ),
                          const SizedBox(height: VSPSpacing.lg),
                          PrimaryButton(
                            text: l10n.buildYourSquad,
                            height: 48,
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
                              if (mounted) setState(() {});
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
              VSPSectionTitle(l10n.account),
              const SizedBox(height: VSPSpacing.sm),
              VSPFadeInItem(
                index: 0,
                child: VSPMenuItem(
                  icon: Iconsax.edit_copy,
                  title: l10n.editProfile,
                  subtitle: l10n.editProfileSubtitle,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 1,
                child: VSPMenuItem(
                  icon: Iconsax.people_copy,
                  title: l10n.myTeam,
                  subtitle: l10n.manageTeamInfo,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
                    if (mounted) setState(() {});
                  },
                ),
              ),
              VSPFadeInItem(
                index: 2,
                child: VSPMenuItem(
                  icon: Iconsax.heart_copy,
                  title: l10n.favoriteStadiums,
                  subtitle: l10n.viewLikedFacilities,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
                ),
              ),
              if (AppConfig.enableOnlinePayment) ...[
                VSPFadeInItem(
                  index: 3,
                  child: VSPMenuItem(
                    icon: Iconsax.wallet_1_copy,
                    title: l10n.paymentMethods,
                    subtitle: l10n.managePaymentMethods,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
                  ),
                ),
              ],

              const SizedBox(height: VSPSpacing.lg),

              // 3. Preferences Section
              VSPSectionTitle(l10n.preferences),
              const SizedBox(height: VSPSpacing.sm),
              VSPFadeInItem(
                index: 4,
                child: Builder(builder: (context) {
                  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                  final govName = auth.userModel?.governorate ?? (isArabic ? 'أسوان' : 'Aswan');
                  final displayGov = isArabic
                      ? (govName == 'Aswan' ? 'أسوان' : (govName == 'Cairo' ? 'القاهرة' : govName))
                      : govName;

                  return VSPMenuItem(
                    icon: Iconsax.location_copy,
                    title: isArabic ? 'الموقع والمحافظة' : 'Location & Governorate',
                    subtitle: isArabic
                        ? 'المحافظة الحالية: $displayGov (اضغط للتغيير)'
                        : 'Current: $displayGov (Tap to change)',
                    onTap: () => _showLocationPicker(context, auth),
                  );
                }),
              ),
              VSPFadeInItem(
                index: 5,
                child: VSPMenuItem(
                  icon: Iconsax.notification_copy,
                  title: l10n.notifications,
                  subtitle: l10n.manageNotificationSettings,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 6,
                child: VSPMenuItem(
                  icon: Iconsax.security_safe_copy,
                  title: l10n.privacy,
                  subtitle: isArabic ? 'الشروط والأحكام وسياسة الخصوصية (PDPL 2020)' : l10n.privacyPolicy,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndPrivacyScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 7,
                child: VSPMenuItem(
                  icon: Iconsax.global_copy,
                  title: l10n.language,
                  subtitle: l10n.manageLanguagePreferences,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
                ),
              ),
              VSPFadeInItem(
                index: 8,
                child: VSPMenuItem(
                  icon: Iconsax.info_circle_copy,
                  title: l10n.helpCenter,
                  subtitle: isArabic ? 'الأسئلة الشائعة وتواصل مع فريق الدعم' : l10n.getHelpSupport,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQAndSupportScreen())),
                ),
              ),

              const SizedBox(height: VSPSpacing.xl),

              // 4. Danger Zone
              VSPFadeInItem(
                index: 9,
                child: VSPMenuItem(
                  icon: Iconsax.logout_copy,
                  title: l10n.logout,
                  subtitle: l10n.signOutAccount,
                  isLogout: true,
                  onTap: () async {
                    await Provider.of<AuthProvider>(context, listen: false).signOut();
                  },
                ),
              ),
              
              SizedBox(height: VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
            ],
          ),
        ),
      ),
    );
  }
}



