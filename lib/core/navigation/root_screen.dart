import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _initRemoteConfig();
    // 📍 Trigger location check and pending deep link check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // Only run for authenticated players (Owners have fixed stadium locations usually)
      if (auth.isAuthenticated && !auth.isOwner) {
        auth.updateUserLocation();
      }

      // معالجة الرابط العميق المعلق بعد نجاح التحقق والدخول
      if (auth.isAuthenticated && auth.userModel != null) {
        _deepLinkChecked = true;
        _handlePendingDeepLink();
      }

      // 🛡️ Safety Net: If user is authenticated but userModel never loads within
      // 5 seconds (e.g. Firestore offline), show a Connection Error screen.
      if (auth.isAuthenticated && auth.userModel == null) {
        _loadingTimeout = Timer(const Duration(seconds: 5), () {
          if (mounted && auth.userModel == null) {
            setState(() => _loadingTimedOut = true);
          }
        });
      }
    });
  }

  // دالة استرجاع وتوجيه المستخدم للرابط العميق المعلق بشكل آمن ومتوافق مع جميع الهياكل
  Future<void> _handlePendingDeepLink() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? pendingLink = prefs.getString('pending_deep_link');
      if (pendingLink != null && mounted) {
        debugPrint('🔗 Recovering pending deep link: $pendingLink');
        await prefs.remove('pending_deep_link'); // حذف الرابط فوراً لمنع التكرار
        
        final uri = Uri.parse(pendingLink);
        String? type;
        String? id;

        if (uri.scheme == 'io.supabase.fluttervsp') {
          type = uri.host;
          if (uri.pathSegments.isNotEmpty) {
            id = uri.pathSegments.first;
          }
        } else {
          if (uri.pathSegments.length >= 2) {
            type = uri.pathSegments[0]; // match or team
            id = uri.pathSegments[1];
          }
        }

        if (type != null && id != null && id.isNotEmpty) {
          // التحقق من سلامة وصحة المعرف لمنع الاختراق
          final bool isValidId = RegExp(r'^[a-zA-Z0-9\-_\s]+$').hasMatch(id);
          if (!isValidId) {
            debugPrint('⚠️ Malicious or garbage ID detected in pending deep link: $id. Redirecting to safe fallback.');
            return;
          }

          if (mounted) {
            if (type == 'match') {
              GoRouter.of(context).push('/match/$id');
            } else if (type == 'team') {
              GoRouter.of(context).push('/team/$id');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error processing pending deep link: $e');
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: const Text('Update Required 🚀', style: TextStyle(color: Colors.white)),
        content: const Text(
          'A new version of VSP is available with improved performance and new features.',
          style: TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          PrimaryButton(
            text: 'Update Now',
            onPressed: () async {
              final Uri storeUri = Uri.parse(url);
              try {
                if (await canLaunchUrl(storeUri)) {
                  await launchUrl(
                    storeUri,
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  debugPrint('Could not launch store URL: $url');
                }
              } catch (e) {
                debugPrint('Error launching store URL: $e');
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

    // 🔗 Reactive Deep Link recovery safety net
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
        statusBarColor: Colors.transparent,
      ),
      child: auth.isOwner ? const OwnerMainScreen() : const PlayerHomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// ��️ Maintenance Mode Screen
// ─────────────────────────────────────────────
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FontAwesomeIcons.gear, size: 80, color: VSPColors.accent),
              const SizedBox(height: VSPSpacing.xl),
              Text(
                'We’ll be back soon!',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VSPSpacing.md),
              const Text(
                'VSP is currently undergoing scheduled maintenance to improve your experience. We apologize for the inconvenience.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VSPColors.textSecondary),
              ),
              const SizedBox(height: VSPSpacing.xl),
              CircularProgressIndicator(color: VSPColors.accent.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}