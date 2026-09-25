import 'package:flutter/material.dart';
import '../../../core/repositories/league_repository.dart';

/// Pure UI trophy badge widget displaying 1v1 championships won.
/// If titles <= 0, renders nothing (SizedBox.shrink()).
/// If titles == 1, renders '🏆 1'.
/// If titles > 1, renders '🏆 ×$titles'.
class Vsp1v1TrophyBadge extends StatelessWidget {
  final int titles;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const Vsp1v1TrophyBadge({
    super.key,
    required this.titles,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    if (titles <= 0) return const SizedBox.shrink();

    final label = titles == 1 ? '🏆 1' : '🏆 ×$titles';

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: const Color(0xFFFFD700),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Async trophy badge widget that automatically fetches the user's 1v1 titles.
/// Renders nothing while loading or if user has 0 titles.
class Vsp1v1UserTrophyBadge extends StatelessWidget {
  final String userId;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const Vsp1v1UserTrophyBadge({
    super.key,
    required this.userId,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<int>(
      future: LeagueRepository().getUser1v1Titles(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final titles = snapshot.data!;
        if (titles <= 0) return const SizedBox.shrink();

        return Vsp1v1TrophyBadge(
          titles: titles,
          fontSize: fontSize,
          padding: padding,
        );
      },
    );
  }
}
