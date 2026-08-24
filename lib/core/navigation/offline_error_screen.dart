import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../ui/tokens/vsp_tokens.dart';
import '../ui/components/vsp_card.dart';

class OfflineErrorScreen extends StatefulWidget {
 const OfflineErrorScreen({super.key});

 @override
 State<OfflineErrorScreen> createState() => _OfflineErrorScreenState();
}

class _OfflineErrorScreenState extends State<OfflineErrorScreen> with SingleTickerProviderStateMixin {
 late AnimationController _pulseController;
 late Animation<double> _pulseAnimation;

 @override
 void initState() {
 super.initState();
 _pulseController = AnimationController(
 vsync: this,
 duration: const Duration(seconds: 2),
 )..repeat(reverse: true);
 
 _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
 CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
 );
 }

 @override
 void dispose() {
 _pulseController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final auth = Provider.of<AuthProvider>(context);
 final isAr = Localizations.localeOf(context).languageCode == 'ar';

 return Scaffold(
 backgroundColor: VSPColors.background,
 body: Stack(
 children: [
 // ── Background Glows for Depth ──
 Positioned(
 top: -100,
 right: -100,
 child: Container(
 width: 300,
 height: 300,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: VSPColors.accent.withValues(alpha: 0.1),
 ),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
 child: Container(color: Colors.transparent),
 ),
 ),
 ),
 Positioned(
 bottom: -150,
 left: -150,
 child: Container(
 width: 400,
 height: 400,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: VSPColors.accent.withValues(alpha: 0.05),
 ),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
 child: Container(color: Colors.transparent),
 ),
 ),
 ),

 // ── Content ──
 Center(
 child: SingleChildScrollView(
 padding: const EdgeInsets.symmetric(horizontal: 24),
 child: ScaleTransition(
 scale: CurvedAnimation(
 parent: ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0),
 curve: Curves.easeOutBack,
 ),
 child: VSPCard(
 isGlass: true,
 padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // ── Pulsing Offline Icon ──
 AnimatedBuilder(
 animation: _pulseAnimation,
 builder: (context, child) {
 return Transform.scale(
 scale: _pulseAnimation.value,
 child: Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.08),
 shape: BoxShape.circle,
 border: Border.all(
 color: VSPColors.accent.withValues(alpha: 0.25),
 width: 2,
 ),
 boxShadow: [
 BoxShadow(
 color: VSPColors.accent.withValues(alpha: 0.15),
 blurRadius: 20,
 spreadRadius: 2,
 )
 ],
 ),
 child: const Icon(
 Iconsax.wifi_square_copy,
 color: VSPColors.accent,
 size: 48,
 ),
 ),
 );
 },
 ),
 const SizedBox(height: 32),

 // ── Title Localized ──
 Text(
 isAr ? 'لا يوجد اتصال بالإنترنت' : 'No Internet Connection',
 style: const TextStyle(
 color: Colors.white,
 fontSize: 22,
 fontWeight: FontWeight.bold,
 letterSpacing: -0.5,
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 12),

 // ── Description Localized ──
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 child: Text(
 isAr 
 ? 'تعذر الاتصال بالشبكة. يرجى التحقق من تفعيل الواي فاي أو بيانات الهاتف ثم إعادة المحاولة.'
 : 'Unable to connect to the network. Please check your Wi-Fi or mobile data and try again.',
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: VSPColors.textSecondary,
 height: 1.6,
 fontSize: 13.5,
 ),
 ),
 ),
 const SizedBox(height: 32),

 // ── Primary Retry Button ──
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: VSPColors.background,
 shadowColor: VSPColors.accent.withValues(alpha: 0.3),
 elevation: 8,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(VSPRadius.md),
 ),
 ),
 onPressed: auth.isLoading ? null : () {
 HapticFeedback.lightImpact();
 auth.retryDataFetch();
 },
 child: auth.isLoading
 ? const SizedBox(
 width: 24,
 height: 24,
 child: CircularProgressIndicator(
 strokeWidth: 2.5,
 valueColor: AlwaysStoppedAnimation<Color>(VSPColors.background),
 ),
 )
 : Text(
 isAr ? 'إعادة المحاولة ' : 'Retry Connection ',
 style: const TextStyle(
 fontWeight: FontWeight.bold,
 fontSize: 15,
 letterSpacing: 0.5,
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 );
 }
}