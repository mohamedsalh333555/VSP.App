import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_error_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../widgets/user_bookings/pending_booking_card.dart';
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
      bookingProvider.loadUserBookings(userId);
      final team = await TeamRepository().getUserTeam(userId);
      if (mounted) {
        setState(() => _myTeamId = team?.id);
      }
    }
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

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
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
            loading: provider.isLoading,
            error: provider.errorMessage,
          ),
          builder: (context, data, child) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            if (data.loading) {
              return const Center(
                child: CircularProgressIndicator(color: VSPColors.accent),
              );
            }

            if (data.error != null && data.upcoming.isEmpty && data.history.isEmpty && data.pending.isEmpty) {
              return VSPErrorState(
                customMessage: data.error,
                onRetry: _loadData,
              );
            }

            if (data.upcoming.isEmpty && data.history.isEmpty && data.pending.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                  final userId = authProvider.currentUser?.uid;
                  if (userId != null) {
                    Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
                    await Future.delayed(const Duration(seconds: 1));
                  }
                },
                color: VSPColors.accent,
                backgroundColor: VSPColors.surface,
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
                  Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
                }
              },
              color: VSPColors.accent,
              backgroundColor: VSPColors.surface,
              child: Builder(builder: (context) {
                final pendingCount = data.pending.length;
                final upcomingCount = data.upcoming.length;
                final historyCount = data.history.length;
                final hasUpcoming = upcomingCount > 0;
                final hasHistory = historyCount > 0;

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPSpacing.md),
                  itemCount: pendingCount +
                      (hasUpcoming ? 1 + upcomingCount : 0) +
                      (hasHistory ? 1 + historyCount : 0),
                  itemBuilder: (context, index) {
                    var cursor = index;
                    if (cursor < pendingCount) {
                      return PendingBookingCard(
                        pendingBooking: data.pending[cursor],
                        isArabic: isArabic,
                      );
                    }
                    cursor -= pendingCount;

                    if (hasUpcoming) {
                      if (cursor == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                          child: Row(
                            children: [
                              const Icon(Iconsax.calendar_tick_copy, size: 18, color: VSPColors.accent),
                              const SizedBox(width: 8),
                              Text(
                                l10n.upcoming,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
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
                              bottom: cursor == upcomingCount - 1 && hasHistory ? VSPSpacing.lg : VSPSpacing.md,
                            ),
                            child: PlayerBookingCard(
                              booking: booking,
                              isHistory: false,
                              myTeamId: _myTeamId,
                            ),
                          ),
                        );
                      }
                      cursor -= upcomingCount;
                    }

                    if (hasHistory) {
                      if (cursor == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasUpcoming) ...[
                              const SizedBox(height: VSPSpacing.sm),
                              const Divider(color: VSPColors.divider, height: 1),
                              const SizedBox(height: VSPSpacing.lg),
                            ],
                            Padding(
                              padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                              child: Row(
                                children: [
                                  const Icon(Iconsax.clock_copy, size: 18, color: VSPColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.history,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: VSPColors.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      cursor -= 1;

                      final booking = data.history[cursor];
                      return VSPFadeInItem(
                        index: cursor + upcomingCount,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                          child: PlayerBookingCard(
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
