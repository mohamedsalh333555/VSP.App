import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import '../../../data/models.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: VSPColors.surface,
          title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: VSPColors.accent,
            labelColor: VSPColors.accent,
            unselectedLabelColor: VSPColors.textSecondary,
            tabs: [
              Tab(text: 'Disputes', icon: Icon(Icons.gavel)),
              Tab(text: 'Reports', icon: Icon(Icons.report)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
             _DisputesTab(),
             _ReportsTab(),
          ],
        ),
      ),
    );
  }
}

class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('matchResultStatus', isEqualTo: 'disputed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gavel, size: 64, color: VSPColors.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text('No disputed matches found', style: TextStyle(color: VSPColors.textSecondary)),
              ],
            ),
          );
        }

        final disputedMatches = snapshot.data!.docs
            .map((doc) => Booking.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: disputedMatches.length,
          itemBuilder: (context, index) {
            return _DisputeCard(booking: disputedMatches[index], onResolved: () {});
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService().getReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.report_gmailerrorred_rounded, size: 64, color: VSPColors.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text('All clean! No reports found.', style: TextStyle(color: VSPColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              color: VSPColors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('${report['targetType'].toString().toUpperCase()} Report', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Reason: ${report['reason']}\nTarget ID: ${report['targetId']}', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                      onPressed: () => _showModerationAction(context, report['targetId'], 'warn'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.block, color: Colors.redAccent),
                      onPressed: () => _showModerationAction(context, report['targetId'], 'suspend'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showModerationAction(BuildContext context, String userId, String action) {
    String message = action == 'warn' ? 'Please follow community guidelines.' : 'Your account has been suspended due to misconduct.';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text('${action == 'warn' ? 'Warn' : 'Suspend'} User', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Action to be taken on user: $userId', style: const TextStyle(color: VSPColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Message to user...',
                hintStyle: const TextStyle(color: Colors.white24),
                fillColor: VSPColors.background,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => message = val,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Cancel',
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: action.toUpperCase(),
                  height: 48,
                  color: action == 'warn' ? Colors.orange : Colors.red,
                  textColor: Colors.white,
                  onPressed: () async {
                    await DatabaseService().updateUserModerationStatus(
                      userId, 
                      isSuspended: action == 'suspend',
                      warningMessage: message,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User ${action == 'warn' ? 'warned' : 'suspended'}')));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onResolved;

  const _DisputeCard({required this.booking, required this.onResolved});

  void _resolveMatch(BuildContext context, MatchOutcome outcome) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: const Text('Confirm Resolution', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to set the outcome as ${outcome.name}?', style: const TextStyle(color: VSPColors.textSecondary)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Cancel',
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: 'Confirm',
                  height: 48,
                  onPressed: () => Navigator.pop(context, true), 
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 1. Force update match result (triggers Elo)
      await DatabaseService().updateMatchResult(
        booking.id, 
        booking.playerTeamId!, 
        booking.opponentTeamId!, 
        outcome
      );

      // 2. Clear dispute status and marks as intervention done
      await FirebaseFirestore.instance.collection('bookings').doc(booking.id).update({
        'matchResultStatus': MatchResultStatus.confirmed.name,
        'requiresAdminIntervention': false,
        'resolvedByAdmin': true,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match resolved successfully'), backgroundColor: VSPColors.accent),
        );
        onResolved();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VSPColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(booking.stadiumName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: VSPColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('DISPUTED', style: TextStyle(color: VSPColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${booking.playerTeamName} VS ${booking.opponentTeamName}', style: TextStyle(color: VSPColors.textSecondary)),
          const Divider(height: 24, color: VSPColors.divider),
          const Text('Determine Winner:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: VSPColors.accent)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: VSPAnimatedButton(
                  text: 'Home Win',
                  onPressed: () => _resolveMatch(context, MatchOutcome.homeWin),
                  color: VSPColors.accent.withValues(alpha: 0.1),
                  textColor: VSPColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VSPAnimatedButton(
                  text: 'Draw',
                  onPressed: () => _resolveMatch(context, MatchOutcome.draw),
                  color: VSPColors.background,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VSPAnimatedButton(
                  text: 'Away Win',
                  onPressed: () => _resolveMatch(context, MatchOutcome.awayWin),
                  color: VSPColors.accent.withValues(alpha: 0.1),
                  textColor: VSPColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
