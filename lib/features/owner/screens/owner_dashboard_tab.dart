import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_stat_card.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/services/database_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';

class OwnerDashboardTab extends StatefulWidget {
  const OwnerDashboardTab({super.key});

  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  final DatabaseService _databaseService = DatabaseService();
  bool _showRevenue = true;

  @override
  void initState() {
    super.initState();
    // Load bookings for the current owner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.firebaseUser?.uid;
      if (uid != null) {
        Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final uid = auth.firebaseUser?.uid;

    if (uid == null) {
      return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
    }

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Financial Overview',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        actions: [
          IconButton(
            icon: Icon(_showRevenue ? Icons.visibility : Icons.visibility_off, color: VSPColors.textSecondary),
            onPressed: () => setState(() => _showRevenue = !_showRevenue),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💰 FINANCIAL STATS SECTION
            FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _databaseService.calculateOwnerRevenue(uid),
                _databaseService.calculateBookedHours(uid),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(VSPSpacing.lg),
                    child: CircularProgressIndicator(color: VSPColors.accent),
                  ));
                }

                final revenue = snapshot.data?[0] as double? ?? 0.0;
                final hours = snapshot.data?[1] as int? ?? 0;

                return Row(
                  children: [
                    Expanded(
                      child: VSPStatCard(
                        label: 'Total Revenue',
                        value: _showRevenue ? '${revenue.toStringAsFixed(0)} EGP' : '**** EGP',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: VSPSpacing.md),
                    Expanded(
                      child: VSPStatCard(
                        label: 'Booked Hours',
                        value: '$hours hrs',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // 🏟️ MY STADIUMS STATUS SECTION
            Text(
              'My Stadiums Status',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.md),

            StreamBuilder<List<Stadium>>(
              stream: _databaseService.getOwnerStadiums(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }

                final stadiums = snapshot.data ?? [];

                if (stadiums.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: stadiums.map((stadium) => _buildStatusStadiumCard(stadium)).toList(),
                );
              },
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStadiumCard(Stadium stadium) {
    final bool isVerified = stadium.isVerified;
    final bookingProvider = Provider.of<BookingProvider>(context);

    final now = DateTime.now();

    // ✅ Filter upcoming bookings for this specific stadium
    final upcomingBookings = bookingProvider.userBookings
        .where((b) =>
            b.stadiumId == stadium.id &&
            b.startTime.isAfter(now) &&
            b.status != BookingStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return VSPCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStadiumHeader(stadium, isVerified),

          // ✅ Upcoming Bookings Section
          if (upcomingBookings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: VSPColors.divider, height: 1),
                  const SizedBox(height: VSPSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.event_note_outlined, color: VSPColors.textSecondary, size: 16),
                      const SizedBox(width: VSPSpacing.xs),
                      Text(
                        "Upcoming Bookings",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  ...upcomingBookings.take(3).map((booking) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
                      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
                      decoration: BoxDecoration(
                        color: VSPColors.background.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.playerTeamName ?? "Individual Player",
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (booking.bookingType == BookingType.challenge)
                                  Text(
                                    "Challenge Match",
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.warning, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 4),
                            decoration: BoxDecoration(
                              color: VSPColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(VSPRadius.sm),
                            ),
                            child: Text(
                              '${booking.startTime.hour}:${booking.startTime.minute.toString().padLeft(2, '0')} - ${booking.endTime.hour}:${booking.endTime.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: VSPColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (upcomingBookings.length > 3)
                    Center(
                      child: Text(
                        "+ ${upcomingBookings.length - 3} more bookings",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStadiumHeader(Stadium stadium, bool isVerified) {
    return Column(
      children: [
        Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(VSPRadius.lg)),
              child: Image.network(
                stadium.imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140,
                  color: VSPColors.surface,
                  child: const Icon(Icons.broken_image, color: VSPColors.textSecondary),
                ),
              ),
            ),
            // Status Badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isVerified ? VSPColors.accent : VSPColors.warning,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: (isVerified ? VSPColors.accent : VSPColors.warning).withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isVerified ? Icons.check_circle : Icons.watch_later,
                      color: Colors.black,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Published' : 'Under Review',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stadium.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    stadium.location,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                  ),
                ],
              ),
              Text(
                '${stadium.pricePerHour} EGP/hr',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: VSPSpacing.xxl, horizontal: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(VSPSpacing.lg),
              decoration: BoxDecoration(
                color: VSPColors.textPrimary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stadium_outlined, color: VSPColors.textSecondary.withValues(alpha: 0.5), size: 64),
            ),
            const SizedBox(height: VSPSpacing.lg),
            Text(
              'Welcome! Start Earning',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.sm),
            Text(
              'Add your first stadium from the menu to start taking bookings and tracking your revenue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

