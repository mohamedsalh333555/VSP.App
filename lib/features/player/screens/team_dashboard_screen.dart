import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:vsp_application/core/utils/vsp_feedback.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../data/models.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/services/support_service.dart';
import '../../../shared/widgets/public_match_card.dart';
import '../../../shared/widgets/team_card_hero.dart';

class TeamDashboardScreen extends StatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen> {
  Team? _userTeam;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchUserTeam();
    // Initial fetch not needed for StreamBuilder anymore
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserTeam() async {
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      final team = await TeamRepository().getUserTeam(auth.currentUser!.uid);
      if (mounted) setState(() => _userTeam = team);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context)!.matchesTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        actions: [
          if (_userTeam != null)
            IconButton(
              icon: Icon(LucideIcons.share2, color: VSPColors.accent),
              onPressed: () => _showTeamCard(context, _userTeam!),
            ),
          IconButton(
            icon: Icon(LucideIcons.headphones, color: VSPColors.textSecondary),
            onPressed: () => SupportService().openSupport(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: StreamBuilder<List<Booking>>(
          stream: MatchRepository().getPublicMatches(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: VSPColors.error),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: VSPSpacing.md),
                itemCount: 5,
                itemBuilder: (context, index) => const CardSkeleton(),
              );
            }
  
            final bookings = snapshot.data ?? [];
  
            if (bookings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.trophy,
                      color: VSPColors.textPrimary.withValues(alpha: 0.1),
                      size: 80,
                    ),
                    const SizedBox(height: VSPSpacing.md),
                    Text(
                      AppLocalizations.of(context)!.noMatchesAvailable,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      AppLocalizations.of(context)!.hostOne,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }
  
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                VSPSpacing.md,
                16,
                MediaQuery.of(context).padding.bottom + 110,
              ),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                  child: PublicMatchCard(
                    booking: bookings[index],
                    highlighted:
                        _userTeam != null &&
                        bookings[index].bookingType == BookingType.team &&
                        bookings[index].playerTeamId != null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showTeamCard(BuildContext context, Team team) {
    VSPFeedback.triggerSuccess();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TeamCardHero(team: team),
            const SizedBox(height: VSPSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(LucideIcons.x),
                  label: Text(AppLocalizations.of(context)!.close),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.surfaceAlt,
                    foregroundColor: VSPColors.textPrimary,
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                ElevatedButton.icon(
                  onPressed: () {
                    SharingService().shareText(
                      AppLocalizations.of(context)!.shareTeamText(team.name, team.rankTitle),
                    );
                  },
                  icon: Icon(LucideIcons.share2),
                  label: Text(AppLocalizations.of(context)!.shareLink),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: VSPColors.background,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
