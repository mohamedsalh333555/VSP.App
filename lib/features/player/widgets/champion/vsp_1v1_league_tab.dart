import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/league_repository.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../screens/paymob_web_view_screen.dart';
import 'champion_podium_components.dart';
import 'league_1v1/league_1v1_empty_states.dart';
import 'league_1v1/league_1v1_hero_card.dart';
import 'league_1v1/league_1v1_prize_card.dart';
import 'league_1v1/league_1v1_registration_action_card.dart';
import 'league_1v1/league_1v1_roster_list.dart';
import 'league_1v1/league_1v1_standings_view.dart';

/// 1v1 individual tournament tab on the Champion screen.
/// Manages active tournament state, Paymob registration, and live podium standings.
class Vsp1v1LeagueTab extends StatefulWidget {
  final String selectedLocation;
  final ValueChanged<String> onLocationChanged;
  final Stream<Map<String, dynamic>?> Function(String) getActive1v1Stream;
  final Stream<List<Map<String, dynamic>>> Function(String) getTournamentPlayersStream;
  final Stream<List<VSP1v1Player>> Function(String?) getStandingsStream;
  final VoidCallback onRetry;

  const Vsp1v1LeagueTab({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.getActive1v1Stream,
    required this.getTournamentPlayersStream,
    required this.getStandingsStream,
    required this.onRetry,
  });

  @override
  State<Vsp1v1LeagueTab> createState() => _Vsp1v1LeagueTabState();
}

class _Vsp1v1LeagueTabState extends State<Vsp1v1LeagueTab> {
  bool _isProcessingPayment = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userGovRaw = auth.userModel?.governorate ?? auth.governorate;
    final userGov = EgyptGovernorates.resolveGoogleName(userGovRaw) ?? userGovRaw;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Fallback prompt if player has no governorate set in profile
    if (userGov.trim().isEmpty) {
      return League1v1NoGovernorateState(isArabic: isArabic);
    }

    // Effective governorate for 1v1: uses widget.selectedLocation (supports curious browsing)
    final effectiveLocation = widget.selectedLocation == 'All' ? userGov : widget.selectedLocation;
    final isBrowsingDifferentGov =
        userGov.isNotEmpty && effectiveLocation.toLowerCase() != userGov.toLowerCase();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: widget.getActive1v1Stream(effectiveLocation),
      builder: (context, tourneySnap) {
        if (tourneySnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final tournament = tourneySnap.data;
        if (tournament == null) {
          final locName = championTranslateItem(context, effectiveLocation);
          return Column(
            children: [
              if (isBrowsingDifferentGov)
                League1v1GovernorateBanner(
                  selectedLocation: widget.selectedLocation,
                  userGov: userGov,
                  isArabic: isArabic,
                  onReturnToHomeGov: () => widget.onLocationChanged(userGov),
                ),
              Expanded(
                child: League1v1NoTournamentState(
                  locationName: locName,
                  isArabic: isArabic,
                ),
              ),
            ],
          );
        }

        final status = tournament['status'] as String? ?? 'registration_open';
        final isCompleted = status == 'completed' || status == 'published';

        return Column(
          children: [
            if (isBrowsingDifferentGov)
              League1v1GovernorateBanner(
                selectedLocation: widget.selectedLocation,
                userGov: userGov,
                isArabic: isArabic,
                onReturnToHomeGov: () => widget.onLocationChanged(userGov),
              ),
            Expanded(
              child: isCompleted
                  ? League1v1StandingsView(
                      standingsStream: widget.getStandingsStream(tournament['id']?.toString()),
                      onRetry: widget.onRetry,
                    )
                  : _build1v1RegistrationPhase(
                      tournament,
                      isBrowsingDifferentGov: isBrowsingDifferentGov,
                      userGov: userGov,
                      isArabic: isArabic,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _build1v1RegistrationPhase(
    Map<String, dynamic> tournament, {
    required bool isBrowsingDifferentGov,
    required String userGov,
    required bool isArabic,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;
    final tournamentId = tournament['id']?.toString() ?? '';
    final tourneyName = tournament['name'] as String? ?? 'بطولة VSP فردي 1vs1';
    final targetCount = (tournament['target_player_count'] as num?)?.toInt() ?? 16;
    final scheduledAt = tournament['scheduled_at'] as String?;
    final status = tournament['status'] as String? ?? 'registration_open';
    final entryFee = (tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
    final prizePool = (tournament['prize_pool'] as num?)?.toDouble() ?? 0.0;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.getTournamentPlayersStream(tournamentId),
      builder: (context, playersSnap) {
        final players = playersSnap.data ?? [];
        final registeredCount = players.length;
        final remainingCount = (targetCount - registeredCount).clamp(0, 999);
        final progress = targetCount > 0 ? (registeredCount / targetCount).clamp(0.0, 1.0) : 0.0;
        final isRegistered = currentUserId != null && players.any((p) => p['user_id'] == currentUserId);
        final myIndex = isRegistered ? players.indexWhere((p) => p['user_id'] == currentUserId) + 1 : null;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Countdown & Timeline Card
              League1v1HeroCard(
                tourneyName: tourneyName,
                governorate: tournament['governorate']?.toString(),
                status: status,
                scheduledAt: scheduledAt,
                registeredCount: registeredCount,
                targetCount: targetCount,
                remainingCount: remainingCount,
                progress: progress,
                isArabic: isArabic,
              ),

              const SizedBox(height: 14),

              // 2. Financial Prize Pool & Entry Fee Transparency Card
              League1v1PrizeCard(
                entryFee: entryFee,
                prizePool: prizePool,
                registeredCount: registeredCount,
                isArabic: isArabic,
              ),

              const SizedBox(height: 14),

              // 3. Interactive Registration Action Card
              League1v1RegistrationActionCard(
                isRegistered: isRegistered,
                myIndex: myIndex,
                isBrowsingDifferentGov: isBrowsingDifferentGov,
                userGov: userGov,
                tournamentGov: tournament['governorate'],
                selectedLocation: widget.selectedLocation,
                status: status,
                remainingCount: remainingCount,
                entryFee: entryFee,
                isProcessingPayment: _isProcessingPayment,
                isArabic: isArabic,
                onJoinPressed: () => _handleJoin1v1(tournamentId, entryFee),
                onSwitchToUserGov: () => widget.onLocationChanged(userGov),
              ),

              const SizedBox(height: 24),

              // 4. Registered Players Roster Table
              League1v1RosterList(
                registeredCount: registeredCount,
                players: players,
                currentUserId: currentUserId,
                isArabic: isArabic,
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleJoin1v1(String tournamentId, double entryFee) async {
    if (_isProcessingPayment) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (user == null) {
      VSPFeedback.showError(context, isArabic ? 'يجب تسجيل الدخول أولاً للمشاركة.' : 'Please log in to join.');
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      // 1. Create atomic payment order on database
      final orderRes = await LeagueRepository().create1v1PaymentOrder(tournamentId);
      if (orderRes['success'] != true) {
        if (!mounted) return;
        VSPFeedback.showError(
          context,
          orderRes['error']?.toString() ??
              (isArabic ? 'فشل إنشاء طلب الاشتراك في البطولة.' : 'Failed to create registration order.'),
        );
        return;
      }

      final orderRef = orderRes['order_reference'] as String;
      final orderAmount = (orderRes['amount'] as num?)?.toDouble() ?? entryFee;

      final userName = auth.userModel?.name ?? 'Player';
      final userPhone = auth.userModel?.phone ?? '';
      final userEmail = user.email ?? 'player@vsp.app';

      // 2. Obtain secure Paymob checkout URL via Supabase Edge Function
      final checkoutUrl = await PaymobService.getCheckoutUrlFromServer(
        amountInEgp: orderAmount,
        bookingId: orderRef,
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        isTournamentPayment: true,
      );

      if (!mounted) return;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        VSPFeedback.showError(
          context,
          isArabic ? 'تعذر فتح بوابة الدفع الآمنة، يرجى المحاولة لاحقاً.' : 'Unable to open secure checkout gateway.',
        );
        return;
      }

      // 3. Open Paymob WebView Screen
      final isPaidSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymobWebViewScreen(
            initialUrl: checkoutUrl,
            title: isArabic ? 'سداد اشتراك البطولة' : 'Tournament Checkout',
            bookingId: orderRef,
          ),
        ),
      );

      if (!mounted) return;

      // 4. Verification Check
      final isRegistered = await LeagueRepository().isUserRegisteredIn1v1(tournamentId, user.uid);
      if (!mounted) return;

      if (isPaidSuccess == true || isRegistered) {
        VSPFeedback.showSuccess(
          context,
          isArabic
              ? 'تم تأكيد الدفع وتسجيلك في البطولة بنجاح!'
              : 'Payment confirmed! You are registered in the tournament.',
        );
        setState(() {});
      } else {
        VSPFeedback.showError(
          context,
          isArabic ? 'لم يتم إتمام الدفع، لم يتم تسجيلك في البطولة.' : 'Payment not completed. You were not registered.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error in _handleJoin1v1: $e');
      VSPFeedback.showError(
        context,
        isArabic ? 'حدث خطأ أثناء معالجة الدفع: $e' : 'Payment error occurred: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }
}
