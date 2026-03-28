import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';
import 'player_home_screen.dart'; 
import '../../owner/screens/tournament_brackets_screen.dart';

class ChampionshipDetailsScreen extends StatefulWidget {
  final Championship championship;

  const ChampionshipDetailsScreen({super.key, required this.championship});

  @override
  State<ChampionshipDetailsScreen> createState() => _ChampionshipDetailsScreenState();
}

class _ChampionshipDetailsScreenState extends State<ChampionshipDetailsScreen> {
  bool _isJoining = false;

  Future<void> _handleJoin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = DatabaseService();

    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.loginToJoinError)));
      return;
    }

    setState(() => _isJoining = true);

    try {
      // 1. Fetch User's Team
      final userPhone = auth.userModel?.phone ?? '';
      final team = await db.getTeamByCaptainPhone(userPhone);

      if (team == null) {
        if (mounted) {
          _showErrorDialog(AppLocalizations.of(context)!.captainRequiredError);
        }
        return;
      }

      // 2. Check Rule: Min 5 Players
      if (team.memberUids.length < 5) {
        if (mounted) {
           _showErrorDialog(AppLocalizations.of(context)!.minPlayersError);
        }
        return;
      }

      // 3. Check if already joined
      if (widget.championship.joinedTeams.contains(team.id)) {
        if (mounted) {
           _showErrorDialog(AppLocalizations.of(context)!.alreadyJoinedError);
        }
        return;
      }

      // 4. Payment Confirmation / Dialog
      if (mounted) {
        final confirmed = await _showPaymentDialog(team);
        if (confirmed == true) {
          final success = await TournamentRepository().joinChampionship(widget.championship.id, team.id);
          if (success && mounted) {
            _showSuccessSnackBar(AppLocalizations.of(context)!.tournamentJoinSuccess(team.name));
            Navigator.pop(context); // Go back after joining
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(AppLocalizations.of(context)!.errorLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.error)),
        content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          PrimaryButton(
            text: AppLocalizations.of(context)!.ok,
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPaymentDialog(Team team) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Column(
          children: [
            const Icon(Icons.payment, color: VSPColors.accent, size: 48),
            const SizedBox(height: VSPSpacing.md),
            Text(
              AppLocalizations.of(context)!.joinConfirmation,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
              AppLocalizations.of(context)!.entryFee(widget.championship.entryFee.toInt(), AppLocalizations.of(context)!.egCurrency),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: VSPColors.accent),
            ),
            const SizedBox(height: VSPSpacing.md),
            Text(
              AppLocalizations.of(context)!.tournamentPaymentDesc,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: AppLocalizations.of(context)!.cancel,
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: AppLocalizations.of(context)!.confirmAndPay,
                  height: 48,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.background, fontWeight: FontWeight.bold)),
        backgroundColor: VSPColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Stack(
        children: [
          // 1. Header Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280, // Taller header to allow overlap
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [VSPColors.background, Colors.transparent],
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.dstIn,
              child: Image.network(
                widget.championship.logoUrl.isNotEmpty 
                  ? widget.championship.logoUrl 
                  : '', // BETA READY: Removed fake logo fallback
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: VSPColors.surfaceAlt,
                  child: const Center(child: Icon(Icons.emoji_events, color: VSPColors.accent, size: 48)),
                ),
              ),
            ),
          ),
          
          // Back & Favorite Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInteractiveCircleIcon(
                    context, 
                    Icons.arrow_back_ios_new, 
                    () => Navigator.of(context).pop(),
                  ),
                  const _FavoriteButton(),
                ],
              ),
            ),
          ),

          // Main Content
          SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
            padding: const EdgeInsets.only(top: 220), // Start below header
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Overlapping Unified Championship Card - Width Fixed to Infinity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: Hero(
                    tag: 'champion_card_${widget.championship.id}',
                    child: SizedBox(
                      width: double.infinity, // Force full width
                      child: ChampionshipCard(championship: widget.championship), 
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Tournament Timeline (Rounds)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: Container(
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                    ),
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(
                               AppLocalizations.of(context)!.schedule,
                               style: Theme.of(context).textTheme.titleMedium,
                             ),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(
                                 color: VSPColors.surfaceAlt,
                                 borderRadius: BorderRadius.circular(VSPRadius.sm),
                               ),
                               child: Text(AppLocalizations.of(context)!.expand, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                             )
                           ],
                         ),
                         const SizedBox(height: VSPSpacing.md),
                         // Vertical timeline
                         _buildTimelineStep(DateFormat('MMM d').format(widget.championship.startDate), AppLocalizations.of(context)!.startDate, true, true),
                         _buildTimelineStep('Match Day 1', AppLocalizations.of(context)!.groupStage, true, true),
                         _buildTimelineStep('Match Day 2', AppLocalizations.of(context)!.quarterFinals, false, true),
                         _buildTimelineStep(DateFormat('MMM d').format(widget.championship.endDate), AppLocalizations.of(context)!.finalMatch, false, false),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 4. Content Sections
                _buildSection(
                  AppLocalizations.of(context)!.aboutTournament,
                  widget.championship.rules.isNotEmpty 
                    ? widget.championship.rules 
                    : AppLocalizations.of(context)!.noDescription,
                ),
                _buildSection(
                  AppLocalizations.of(context)!.matchRules,
                  AppLocalizations.of(context)!.matchRulesContent(widget.championship.matchDuration),
                ),
                _buildSection(
                  AppLocalizations.of(context)!.importantInstructions,
                  AppLocalizations.of(context)!.importantInstructionsContent,
                ),

                const SizedBox(height: 100), // Space for Join Button
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
        child: (widget.championship.status == 'ongoing' || widget.championship.status == 'completed')
            ? PrimaryButton(
                text: AppLocalizations.of(context)!.viewBrackets,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TournamentBracketsScreen(
                        championship: widget.championship,
                        isOwner: false,
                      ),
                    ),
                  );
                },
              )
            : PrimaryButton(
                text: AppLocalizations.of(context)!.join,
                isLoading: _isJoining,
                onPressed: _handleJoin,
              ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, VSPSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.sm),
          Text(
            content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: VSPColors.textSecondary.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String date, String title, bool isActive, bool hasNext) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isActive ? VSPColors.textPrimary : VSPColors.divider.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                if (hasNext)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: VSPColors.divider.withValues(alpha: 0.1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isActive ? VSPColors.textPrimary : VSPColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: VSPColors.textSecondary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isActive ? VSPColors.textPrimary.withValues(alpha: 0.7) : VSPColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCircleIcon(BuildContext context, IconData icon, VoidCallback onTap, {Color? color}) {
    final iconColor = color ?? VSPColors.textPrimary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: VSPColors.background.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: iconColor, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton();

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool isFav = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: VSPColors.background.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          color: isFav ? VSPColors.error : VSPColors.textPrimary,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            isFav = !isFav;
          });
        },
      ),
    );
  }
}
