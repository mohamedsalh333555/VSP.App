import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/repositories/challenge_repository.dart';

class ConfirmChallengeDialog extends StatelessWidget {
 final ChallengeResult result;
 final ChallengeRepository repository = ChallengeRepository();

 ConfirmChallengeDialog({super.key, required this.result});

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
 title: const Row(
 children: [
 Icon(Iconsax.cup_copy, color: VSPColors.accent),
 SizedBox(width: 8),
 Text(
 "تأكيد نتيجة التحدي ",
 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
 ),
 ],
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 decoration: BoxDecoration(
 color: VSPColors.background,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Text(
 "${result.team1Score} - ${result.team2Score}",
 style: const TextStyle(color: VSPColors.accent, fontSize: 28, fontWeight: FontWeight.w900),
 ),
 ),
 const SizedBox(height: 16),
 const Text(
 "تأكد من مطابقة النتيجة الفعلية للمباراة قبل النقر على تأكيد.",
 textAlign: TextAlign.center,
 style: TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () async {
 final nav = Navigator.of(context);
 await repository.confirmChallengeResult(context, resultId: result.id, approve: false);
 nav.pop(false);
 },
 child: const Text(" اعتراض / النتيجة خاطئة", style: TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
 ),
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 onPressed: () async {
 final nav = Navigator.of(context);
 await repository.confirmChallengeResult(context, resultId: result.id, approve: true);
 nav.pop(true);
 },
 child: const Text(" تأكيد النتيجة", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
 ),
 ],
 );
 }
}
