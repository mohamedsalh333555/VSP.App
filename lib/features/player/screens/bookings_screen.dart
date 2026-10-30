import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/ui/tokens/vsp_design_tokens.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_error_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../widgets/user_bookings/pending_booking_card.dart';
import '../widgets/user_bookings/open_join_booking_card.dart';
import '../widgets/user_bookings/player_booking_card.dart';
import 'player_home_screen.dart';

/// Screen displaying player bookings divided into pending, upcoming, and history with full match lifecycle actions.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String? _myTeamId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    final userId = authProvider.currentUser?.uid;
    if (userId != null) {
      await bookingProvider.loadUserBookings(userId);
      if (!mounted) return;
      final team = await TeamRepository().getUserTeam(userId);
      if (mounted) {
        setState(() => _myTeamId = team?.id);
      }
    }
  }

  Widget _buildSyncWarning(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: VSPDSSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: VSPDSSpacing.sm,
        vertical: VSPDSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VSPDSRadius.md),
        border: Border.all(color: errorColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.info_circle_copy, color: errorColor, size: 18),
          const SizedBox(width: VSPDSSpacing.sm),
          Expanded(
            child: Text(
              isArabic
                  ? 'تعذر تحديث الحجوزات. يتم عرض آخر بيانات تم تحميلها.'
                  : 'Could not refresh bookings. Showing the last loaded data.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: errorColor,
                  ),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return VSPEmptyState(
      icon: Iconsax.calendar_1_copy,
      title: l10n.noBookings,
      subtitle: l10n.noBookingsSubtitle,
      buttonText: l10n.exploreStadiums,
      onButtonPressed: () {
        if (playerHomeScreenKey.currentState != null) {
          playerHomeScreenKey.currentState?.switchToTab(0);
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return VSPScaffold(
      backgroundColor: VSPDSSemanticColors.background,
      appBar: AppBar(
        backgroundColor: VSPDSSemanticColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          l10n.bookedTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Selector<BookingProvider, ({List<Booking> upcoming, List<Booking> history, List<Booking> pending, bool loading, String? error})>(
          selector: (_, provider) => (
            upcoming: provider.upcomingBookings,
            history: provider.historyBookings,
            pending: provider.pendingBookings,
            loading: provider.isLoadingUserBookings,
            error: provider.errorMessage,
          ),
          builder: (context, data, child) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            final hasBookings =
                data.upcoming.isNotEmpty || data.history.isNotEmpty || data.pending.isNotEmpty;

            if (data.loading && !hasBookings) {
              return const Center(
                child: CircularProgressIndicator(color: VSPDSSemanticColors.accent),
              );
            }

            if (data.error != null && !hasBookings) {
              return VSPErrorState(
                customMessage: isArabic
                    ? 'تعذر تحميل حجوزاتك. تحقق من اتصالك ثم حاول مرة أخرى.'
                    : 'Could not load your bookings. Check your connection and try again.',
                onRetry: _loadData,
              );
            }

            if (data.upcoming.isEmpty && data.history.isEmpty && data.pending.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                  final userId = authProvider.currentUser?.uid;
                  if (userId != null) {
                    await Provider.of<BookingProvider>(context, listen: false)
                        .loadUserBookings(userId);
                  }
                },
                color: VSPDSSemanticColors.accent,
                backgroundColor: VSPDSSemanticColors.surface,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: _buildEmptyState(),
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                final userId = authProvider.currentUser?.uid;
                if (userId != null) {
                  await Provider.of<BookingProvider>(context, listen: false)
                      .loadUserBookings(userId);
                }
              },
              color: VSPDSSemanticColors.accent,
              backgroundColor: VSPDSSemanticColors.surface,
              child: Builder(builder: (context) {
                final pendingCount = data.pending.length;
                final upcomingCount = data.upcoming.length;
                final historyCount = data.history.length;
                final hasUpcoming = upcomingCount > 0;
                final hasHistory = historyCount > 0;
                final hasSyncError = data.error != null;

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: VSPDSScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPDSSpacing.sm),
                  itemCount: (hasSyncError ? 1 : 0) + pendingCount +
                      (hasUpcoming ? 1 + upcomingCount : 0) +
                      (hasHistory ? 1 + historyCount : 0),
                  itemBuilder: (context, index) {
                    if (hasSyncError && index == 0) {
                      return _buildSyncWarning(context);
                    }
                    var cursor = hasSyncError ? index - 1 : index;

                    // Visual priority: Upcoming → Pending → History.
                    if (hasUpcoming) {
                      if (cursor == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: VSPDSSpacing.sm),
                          child: Text(
                            l10n.upcoming,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        );
                      }
                      cursor -= 1;

                      if (cursor < upcomingCount) {
                        final booking = data.upcoming[cursor];
                        return VSPFadeInItem(
                          index: cursor,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: cursor == upcomingCount - 1 &&
                                      (pendingCount > 0 || hasHistory)
                                  ? VSPDSSpacing.md
                                  : VSPDSSpacing.sm,
                            ),
                            child: booking.bookingType == BookingType.openJoin
                                ? OpenJoinBookingCard(booking: booking, isHistory: false)
                                : PlayerBookingCard(
                                    booking: booking,
                                    isHistory: false,
                                    myTeamId: _myTeamId,
                                  ),
                          ),
                        );
                      }
                      cursor -= upcomingCount;
                    }

                    if (cursor < pendingCount) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: VSPDSSpacing.sm),
                        child: PendingBookingCard(
                          pendingBooking: data.pending[cursor],
                          isArabic: isArabic,
                        ),
                      );
                    }
                    cursor -= pendingCount;

                    if (hasHistory) {
                      if (cursor == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: VSPDSSpacing.sm),
                          child: Text(
                            l10n.history,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        );
                      }
                      cursor -= 1;

                      final booking = data.history[cursor];
                      return VSPFadeInItem(
                        index: cursor + upcomingCount,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: VSPDSSpacing.sm),
                          child: booking.bookingType == BookingType.openJoin
                              ? OpenJoinBookingCard(booking: booking, isHistory: true)
                              : PlayerBookingCard(
                                  booking: booking,
                                  isHistory: true,
                                  myTeamId: _myTeamId,
                                ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
