import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class VSPProLockedCard extends StatelessWidget {
 final Widget child;
 final String title;
 final String featureTag;
 final String benefitText;
 final bool isPro;
 final VoidCallback onUpgradeTap;

 const VSPProLockedCard({
 super.key,
 required this.child,
 required this.title,
 required this.featureTag,
 required this.benefitText,
 required this.isPro,
 required this.onUpgradeTap,
 });

 @override
 Widget build(BuildContext context) {
 if (isPro) {
 return child; // إذا كان المالك مشتركاً، يظهر الكارت كاملاً وبدون تغبيش
 }

 return Container(
 margin: const EdgeInsets.only(bottom: VSPSpacing.md),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 child: Stack(
 children: [
 // البيانات خلف التغبيش
 IgnorePointer(
 child: child,
 ),

 // طبقة التغبيش الزجاجي
 Positioned.fill(
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
 child: Container(
 color: Colors.black.withValues(alpha: 0.45),
 ),
 ),
 ),

 // كارت الدعوة للاشتراك فوق التغبيش
 Positioned.fill(
 child: Padding(
 padding: const EdgeInsets.all(16.0),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: Colors.amber.withValues(alpha: 0.15),
 shape: BoxShape.circle,
 border: Border.all(color: Colors.amber, width: 1.5),
 ),
 child: const Icon(Iconsax.lock_copy, color: Colors.amber, size: 22),
 ),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: Colors.amber,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 'VSP PRO $featureTag',
 style: const TextStyle(
 color: Colors.black,
 fontWeight: FontWeight.w900,
 fontSize: 10,
 letterSpacing: 1.0,
 ),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 benefitText,
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 12,
 fontWeight: FontWeight.bold,
 height: 1.4,
 ),
 ),
 const SizedBox(height: 12),
 ElevatedButton.icon(
 onPressed: onUpgradeTap,
 icon: const Icon(Iconsax.magic_star_copy, size: 16, color: Colors.black),
 label: const Text(
 'ترقية واكتشاف التحليلات',
 style: TextStyle(
 color: Colors.black,
 fontWeight: FontWeight.w900,
 fontSize: 12,
 ),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.amber,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
 elevation: 4,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }
}
