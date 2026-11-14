import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import '../../shared/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../features/owner/screens/owner_main_screen.dart';
import '../../features/player/screens/player_home_screen.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import 'dart:async';
import '../services/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/deep_link_helper.dart';
import '../services/logger_service.dart';
import '../../l10n/app_localizations.dart';
import 'offline_error_screen.dart';

import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class RootScreen extends StatefulWidget {
 const RootScreen({super.key});

 @override
 State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
 Timer? _loadingTimeout;
 bool _deepLinkChecked = false;
 // ignore: unused_field
 bool _loadingTimedOut = false;
 String? _loadingUserId;

 @override
 void initState() {
 super.initState();
 _initRemoteConfig();
 // Trigger location check and pending deep link check after first frame
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 final auth = Provider.of<AuthProvider>(context, listen: false);
 // معالجة الرابط العميق المعلق بعد نجاح التحقق والدخول
 if (auth.isAuthenticated && auth.userModel != null) {
 _deepLinkChecked = true;
 _handlePendingDeepLink();
 }

 });
 }

 @override
 void didChangeDependencies() {
   super.didChangeDependencies();
   final auth = Provider.of<AuthProvider>(context);
   final userId = auth.currentUser?.id;

   if (!auth.isAuthenticated || auth.userModel != null || userId == null) {
     _loadingTimeout?.cancel();
     _loadingTimeout = null;
     _loadingUserId = null;
     if (_loadingTimedOut) _loadingTimedOut = false;
     return;
   }

   if (_loadingUserId == userId && _loadingTimeout != null) return;

   _loadingTimeout?.cancel();
   _loadingUserId = userId;
   _loadingTimedOut = false;
   _loadingTimeout = Timer(const Duration(seconds: 5), () {
     if (!mounted) return;
     final currentAuth = Provider.of<AuthProvider>(context, listen: false);
     if (currentAuth.currentUser?.id == userId &&
         currentAuth.isAuthenticated &&
         currentAuth.userModel == null) {
       setState(() => _loadingTimedOut = true);
     }
   });
 }

 // دالة استرجاع وتوجيه المستخدم للرابط العميق المعلق بشكل آمن ومتوافق مع جميع الهياكل
 Future<void> _handlePendingDeepLink() async {
 try {
 final prefs = await SharedPreferences.getInstance();
 final String? pendingLink = prefs.getString('pending_deep_link');
 if (pendingLink != null && mounted) {
 VSPLogger.i('Recovering pending deep link');
 await prefs.remove('pending_deep_link'); // حذف الرابط فوراً لمنع التكرار

 final uri = Uri.parse(pendingLink);
 final parsed = DeepLinkHelper.parse(uri);
 if (parsed != null && mounted) {
 GoRouter.of(context).push(parsed.routePath);
 }
 }
 } catch (e, stackTrace) {
 VSPLogger.e('Failed to process pending deep link', e, stackTrace);
 }
 }

 Future<void> _initRemoteConfig() async {
 final remoteConfig = RemoteConfigService();
 await remoteConfig.initialize();
 if (mounted) setState(() {});
 
 final shouldUpdate = await remoteConfig.shouldForceUpdate();
 if (shouldUpdate && mounted) {
 _showForceUpdateDialog(remoteConfig.forceUpdateUrl);
 }
 }

 void _showForceUpdateDialog(String url) {
 final l10n = AppLocalizations.of(context)!;
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) => AlertDialog(
      scrollable: true,
 backgroundColor: VSPColors.surface,
 title: Text(
 l10n.updateRequired,
 style: const TextStyle(color: VSPColors.white),
 ),
 content: Text(
 l10n.updateAvailableMessage,
 style: const TextStyle(color: VSPColors.textSecondary),
 ),
 actions: [
 PrimaryButton(
 text: l10n.updateNow,
 onPressed: () async {
 final Uri storeUri = Uri.parse(url);
 try {
 if (await canLaunchUrl(storeUri)) {
 await launchUrl(
 storeUri,
 mode: LaunchMode.externalApplication,
 );
 } else {
 VSPLogger.w('Could not launch update URL');
 }
 } catch (e) {
 VSPLogger.e('Error launching update URL', e);
 }
 },
 ),
 ],
 ),
 );
 }

 @override
 void dispose() {
 _loadingTimeout?.cancel();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final auth = context.watch<AuthProvider>();
 final remoteConfig = context.watch<RemoteConfigService>();

 if (remoteConfig.isMaintenanceMode) {
 return const MaintenanceScreen();
 }

 // Never choose the Player shell until the authenticated profile has resolved; this prevents an owner/player flicker.
 if (auth.isAuthenticated && auth.userModel == null) {
   if (_loadingTimedOut) return const OfflineErrorScreen();
   final isArabic = Localizations.localeOf(context).languageCode == 'ar';
   return VSPScaffold(
     backgroundColor: VSPColors.background,
     body: SafeArea(
       child: VSPStateView(
         state: VSPUiState.loading,
         title: isArabic ? 'جارٍ تجهيز حسابك' : 'Preparing your account',
         message: isArabic
             ? 'نحمّل بيانات حسابك قبل فتح الصفحة الرئيسية.'
             : 'Loading your account details before opening the home screen.',
       ),
     ),
   );
 }

 // Reactive Deep Link recovery safety net
 if (auth.isAuthenticated && auth.userModel != null && !_deepLinkChecked) {
 _deepLinkChecked = true;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (mounted) {
 _handlePendingDeepLink();
 }
 });
 } else if (!auth.isAuthenticated && _deepLinkChecked) {
 _deepLinkChecked = false;
 }

 return AnnotatedRegion<SystemUiOverlayStyle>(
 value: SystemUiOverlayStyle.light.copyWith(
 statusBarColor: VSPColors.transparent,
 ),
 child: auth.isOwner ? const OwnerMainScreen() : PlayerHomeScreen(key: playerHomeScreenKey),
 );
 }
}

// ─────────────────────────────────────────────
// �� Maintenance Mode Screen
// ─────────────────────────────────────────────
class MaintenanceScreen extends StatelessWidget {
 const MaintenanceScreen({super.key});

 @override
 Widget build(BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return VSPScaffold(
 backgroundColor: VSPColors.background,
 body: SafeArea(
 child: Center(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(VSPSpacing.xl),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Iconsax.setting_2_copy, size: 80, color: VSPColors.accent),
 const SizedBox(height: VSPSpacing.xl),
 Text(
 isArabic ? 'سنعود قريباً!' : 'We’ll be back soon!',
 style: Theme.of(context).textTheme.displaySmall,
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: VSPSpacing.md),
 Text(
 isArabic
     ? 'تجري حالياً صيانة مجدولة لتحسين تجربة الاستخدام. نعتذر عن الإزعاج.'
     : 'VSP is currently undergoing scheduled maintenance to improve your experience. We apologize for the inconvenience.',
 textAlign: TextAlign.center,
 style: const TextStyle(color: VSPColors.textSecondary),
 ),
 const SizedBox(height: VSPSpacing.xl),
 CircularProgressIndicator(color: VSPColors.accent.withValues(alpha: 0.5)),
 ],
 ),
 ),
 ),
 ),
 );
 }
}