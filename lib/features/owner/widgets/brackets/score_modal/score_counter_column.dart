import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class ScoreCounterColumn extends StatelessWidget {
  final String teamName;
  final int score;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const ScoreCounterColumn({
    super.key,
    required this.teamName,
    required this.score,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          teamName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onDecrement,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: VSPColors.surfaceAlt, shape: BoxShape.circle),
                child: const Icon(Iconsax.minus_cirlce_copy, color: Colors.white, size: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$score',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
              ),
            ),
            GestureDetector(
              onTap: onIncrement,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
                child: const Icon(Iconsax.add_circle_copy, color: Colors.black, size: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
