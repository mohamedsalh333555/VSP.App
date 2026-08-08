import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class VSPCountdownTimer extends StatefulWidget {
  final DateTime targetDate;
  final bool isCompact;

  const VSPCountdownTimer({
    super.key,
    required this.targetDate,
    this.isCompact = false,
  });

  @override
  State<VSPCountdownTimer> createState() => _VSPCountdownTimerState();
}

class _VSPCountdownTimerState extends State<VSPCountdownTimer> {
  Timer? _timer;
  late Duration _timeRemaining;

  @override
  void initState() {
    super.initState();
    _calculateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _calculateTimeRemaining();
      }
    });
  }

  void _calculateTimeRemaining() {
    final now = DateTime.now();
    final difference = widget.targetDate.difference(now);
    setState(() {
      _timeRemaining = difference.isNegative ? Duration.zero : difference;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (_timeRemaining == Duration.zero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: VSPColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(VSPRadius.sm),
        ),
        child: Text(
          isArabic ? '🔥 البطولة انطلقت الآن!' : '🔥 Tournament Started!',
          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }

    final days = _timeRemaining.inDays;
    final hours = _timeRemaining.inHours % 24;
    final minutes = _timeRemaining.inMinutes % 60;
    final seconds = _timeRemaining.inSeconds % 60;

    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: VSPColors.background.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(VSPRadius.sm),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, color: VSPColors.accent, size: 12),
            const SizedBox(width: 4),
            Text(
              '${days}d ${hours}h ${minutes}m',
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: VSPColors.accent, size: 14),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'ينتهي التسجيل وتبدأ البطولة خلال:' : 'Registration Closes In:',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeUnit(days.toString().padLeft(2, '0'), isArabic ? 'يوم' : 'Days'),
              _buildColon(),
              _buildTimeUnit(hours.toString().padLeft(2, '0'), isArabic ? 'ساعة' : 'Hours'),
              _buildColon(),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), isArabic ? 'دقيقة' : 'Mins'),
              _buildColon(),
              _buildTimeUnit(seconds.toString().padLeft(2, '0'), isArabic ? 'ثانية' : 'Secs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: VSPColors.divider, width: 0.5),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildColon() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        ':',
        style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
