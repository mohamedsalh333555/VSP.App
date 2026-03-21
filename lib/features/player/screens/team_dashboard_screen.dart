import 'package:flutter/material.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/utils/vsp_feedback.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/providers/booking_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../data/models.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/public_match_card.dart';

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
    _scrollController.addListener(_onScroll);
    
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchPublicMatches(isRefresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<BookingProvider>().fetchPublicMatches();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserTeam() async {
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      final team = await DatabaseService().getUserTeam(auth.currentUser!.uid);
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
          'Matches',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.publicMatches.isEmpty) {
            return ListView.builder(
              padding: const EdgeInsets.all(VSPSpacing.md),
              itemCount: 5,
              itemBuilder: (context, index) => const CardSkeleton(),
            );
          }
          
          final bookings = provider.publicMatches;
          
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.sports_soccer_outlined, color: Colors.white.withValues(alpha: 0.1), size: 80),
                   const SizedBox(height: VSPSpacing.md),
                    Text(
                    'No public matches available right now.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Be the first to host one!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchPublicMatches(isRefresh: true),
            color: VSPColors.accent,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 110),
              itemCount: bookings.length + (provider.isLoadingMoreMatches ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == bookings.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(VSPSpacing.md),
                      child: CircularProgressIndicator(color: VSPColors.accent),
                    ),
                  );
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                  child: PublicMatchCard(
                    booking: bookings[index],
                    highlighted: _userTeam != null && 
                               bookings[index].bookingType == BookingType.team &&
                               bookings[index].playerTeamId != null, 
                  ),
                );
              },
            ),
          );
        }
      ),
    );
  }
}


