import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/match_repository.dart';
import '../../../../core/repositories/notification_repository.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/components/vsp_section_title.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/public_match_card.dart';
import '../../screens/notifications_center_screen.dart';
import '../championship_card.dart';

/// عنوان القسم الرئيسي مع خيار عرض الكل
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const HomeSectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          VSPSectionTitle(title),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                AppLocalizations.of(context)!.seeAll,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// زر شارة الإشعارات في الشريط العلوي للصفحة الرئيسية
class HomeNotificationBadge extends StatefulWidget {
  final String userId;
  const HomeNotificationBadge({super.key, required this.userId});

  @override
  State<HomeNotificationBadge> createState() => _HomeNotificationBadgeState();
}

class _HomeNotificationBadgeState extends State<HomeNotificationBadge> {
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = NotificationRepository().getUnreadNotificationCount(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data ?? 0) > 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Iconsax.notification_copy, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
              ),
            ),
            if (hasUnread)
              Positioned(
                top: 8,
                right: 8,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (ctx, val, _) => Transform.scale(
                    scale: val,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: VSPColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.error.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// قسم المباريات المفتوحة في الصفحة الرئيسية
class HomeMatchesSection extends StatefulWidget {
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;
  const HomeMatchesSection({super.key, required this.onNavigate});

  @override
  State<HomeMatchesSection> createState() => _HomeMatchesSectionState();
}

class _HomeMatchesSectionState extends State<HomeMatchesSection> {
  late final Stream<List<Booking>> _matchesStream;

  @override
  void initState() {
    super.initState();
    _matchesStream = MatchRepository().getPublicMatches();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _matchesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Matches Stream Error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            HomeSectionHeader(
              title: AppLocalizations.of(context)!.joinMatches,
              onSeeAll: () => widget.onNavigate(1),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: matches.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: matches.length,
                      itemBuilder: (context, i) => Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 320,
                          margin: const EdgeInsets.only(right: 6),
                          child: PublicMatchCard(booking: matches[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// قسم البطولات المتاحة في الصفحة الرئيسية
class HomeChampionshipsSection extends StatefulWidget {
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;
  const HomeChampionshipsSection({super.key, required this.onNavigate});

  @override
  State<HomeChampionshipsSection> createState() => _HomeChampionshipsSectionState();
}

class _HomeChampionshipsSectionState extends State<HomeChampionshipsSection> {
  late final Stream<List<Championship>> _championshipsStream;

  @override
  void initState() {
    super.initState();
    _championshipsStream = TournamentRepository().getChampionshipsStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Championship>>(
      stream: _championshipsStream,
      builder: (context, snapshot) {
        final championships = snapshot.data ?? [];
        if (championships.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            HomeSectionHeader(
              title: AppLocalizations.of(context)!.joinChampionships,
              onSeeAll: () => widget.onNavigate(2, arguments: {'initialTab': 0}),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: championships.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: championships.length,
                      itemBuilder: (context, i) => Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 320,
                          margin: const EdgeInsets.only(right: 6),
                          child: ChampionshipCard(championship: championships[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
