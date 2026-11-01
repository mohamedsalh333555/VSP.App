import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/match_repository.dart';
import '../../../../core/repositories/notification_repository.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/components/vsp_section_title.dart';
import '../../../../core/ui/vsp_ui.dart';
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
  late Stream<List<Booking>> _matchesStream;

  @override
  void initState() {
    super.initState();
    _matchesStream = MatchRepository().getPublicMatches();
  }

  void _retryMatches() {
    setState(() {
      _matchesStream = MatchRepository().getPublicMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _matchesStream,
      builder: (context, snapshot) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        final matches = snapshot.data ?? [];
        if (snapshot.hasError && matches.isEmpty) {
          debugPrint('Matches Stream Error: ${snapshot.error}');
          return VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر تحميل المباريات' : 'Could not load matches',
            message: isArabic
                ? 'حصلت مشكلة أثناء تحميل المباريات. حاول مرة تانية.'
                : 'We could not load matches right now. Please try again.',
            onRetry: _retryMatches,
          );
        }
        final isLoading = snapshot.connectionState == ConnectionState.waiting && matches.isEmpty;

        return Column(
          children: [
            if (snapshot.hasError)
              _HomeFeedStaleWarning(
                isArabic: isArabic,
                onRetry: _retryMatches,
              ),
            HomeSectionHeader(
              title: AppLocalizations.of(context)!.joinMatches,
              onSeeAll: matches.isNotEmpty ? () => widget.onNavigate(1) : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: isLoading
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : matches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.cup_copy, size: 40, color: VSPColors.textSecondary.withValues(alpha: 0.4)),
                              const SizedBox(height: 10),
                              Text(
                                Localizations.localeOf(context).languageCode == 'ar'
                                    ? 'لا توجد مباريات مفتوحة حالياً'
                                    : 'No open matches right now',
                                style: TextStyle(
                                  color: VSPColors.textSecondary.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Localizations.localeOf(context).languageCode == 'ar'
                                    ? 'احجز ملعبك وافتح مباراة للجميع!'
                                    : 'Book a pitch and open a match for everyone!',
                                style: TextStyle(
                                  color: VSPColors.textSecondary.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: matches.length,
                          itemBuilder: (context, i) => Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              width: 320,
                              margin: const EdgeInsetsDirectional.only(end: 6),
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
  late Stream<List<Championship>> _championshipsStream;

  @override
  void initState() {
    super.initState();
    _championshipsStream = TournamentRepository().getChampionshipsStream();
  }

  void _retryChampionships() {
    setState(() {
      _championshipsStream = TournamentRepository().getChampionshipsStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Championship>>(
      stream: _championshipsStream,
      builder: (context, snapshot) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        final championships = snapshot.data ?? [];
        if (snapshot.hasError && championships.isEmpty) {
          debugPrint('Championships Stream Error: ${snapshot.error}');
          return VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر تحميل البطولات' : 'Could not load tournaments',
            message: isArabic
                ? 'حصلت مشكلة أثناء تحميل البطولات. حاول مرة تانية.'
                : 'We could not load tournaments right now. Please try again.',
            onRetry: _retryChampionships,
          );
        }
        final isLoading = snapshot.connectionState == ConnectionState.waiting && championships.isEmpty;

        return Column(
          children: [
            if (snapshot.hasError)
              _HomeFeedStaleWarning(
                isArabic: isArabic,
                onRetry: _retryChampionships,
              ),
            HomeSectionHeader(
              title: AppLocalizations.of(context)!.joinChampionships,
              onSeeAll: championships.isNotEmpty
                  ? () => widget.onNavigate(2, arguments: {'initialTab': 0})
                  : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: isLoading
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : championships.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.cup_copy, size: 40, color: VSPColors.textSecondary.withValues(alpha: 0.4)),
                              const SizedBox(height: 10),
                              Text(
                                isArabic
                                    ? 'لا توجد بطولات متاحة حالياً'
                                    : 'No tournaments available right now',
                                style: TextStyle(
                                  color: VSPColors.textSecondary.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isArabic
                                    ? 'ترقب قريباً — البطولة القادمة في الطريق!'
                                    : 'Stay tuned — the next tournament is on the way!',
                                style: TextStyle(
                                  color: VSPColors.textSecondary.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: championships.length,
                          itemBuilder: (context, i) => Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              width: 320,
                              margin: const EdgeInsetsDirectional.only(end: 6),
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

class _HomeFeedStaleWarning extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onRetry;

  const _HomeFeedStaleWarning({
    required this.isArabic,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 16),
          const SizedBox(width: VSPSpacing.xs),
          Expanded(
            child: Text(
              isArabic
                  ? 'تعذر التحديث. المعروض آخر بيانات تم تحميلها.'
                  : 'Refresh failed. Showing the last loaded data.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
