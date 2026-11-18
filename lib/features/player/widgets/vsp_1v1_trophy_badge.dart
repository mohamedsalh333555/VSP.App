import 'package:flutter/material.dart';
import '../../../core/repositories/league_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Historical 1v1 trophies remain visible for records, but never represent
/// a currently available 1v1 tournament or a Team Skills Cup title.
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final description = isArabic
        ? 'ألقاب 1 ضد 1 التاريخية: $titles'
        : 'Historical 1v1 titles: $titles';
    final label = titles == 1 ? '🏆 1' : '🏆 ×$titles';

    return Semantics(
      container: true,
      label: description,
      child: ExcludeSemantics(
        child: Tooltip(
          message: description,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: VSPColors.medalGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(VSPRadius.chip),
              border: Border.all(
                color: VSPColors.medalGold.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: VSPColors.medalGold,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cache the verified historical lookup for each account. Rebuilding the
/// profile must not issue another request or briefly show the prior account's
/// trophy count while a new identity is being checked.
class Vsp1v1UserTrophyBadge extends StatefulWidget {
  final String userId;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Future<int> Function(String userId)? loadTitles;

  const Vsp1v1UserTrophyBadge({
    super.key,
    required this.userId,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    this.loadTitles,
  });

  @override
  State<Vsp1v1UserTrophyBadge> createState() => _Vsp1v1UserTrophyBadgeState();
}

class _Vsp1v1UserTrophyBadgeState extends State<Vsp1v1UserTrophyBadge> {
  late Future<int> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant Vsp1v1UserTrophyBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.loadTitles != widget.loadTitles) {
      _refresh();
    }
  }

  void _refresh() {
    if (widget.userId.trim().isEmpty) {
      _future = Future<int>.value(0);
    } else {
      _future = widget.loadTitles?.call(widget.userId) ??
          LeagueRepository().getUser1v1Titles(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.trim().isEmpty) return const SizedBox.shrink();
    return FutureBuilder<int>(
      future: _future,
      builder: (context, snapshot) {
        // A FutureBuilder may retain the *previous user's* data while the
        // replacement future is waiting. Never show that stale trophy count.
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError || !snapshot.hasData ||
            (snapshot.data ?? 0) <= 0) {
          return const SizedBox.shrink();
        }
        return Vsp1v1TrophyBadge(
          titles: snapshot.data!,
          fontSize: widget.fontSize,
          padding: widget.padding,
        );
      },
    );
  }
}
