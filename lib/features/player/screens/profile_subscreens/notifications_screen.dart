import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/language_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _generalNotifications = true;
  bool _soundAlerts = true;
  bool _pushNotifications = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _generalNotifications = prefs.getBool('notif_general') ?? true;
      _soundAlerts = prefs.getBool('notif_sound') ?? true;
      _pushNotifications = prefs.getBool('notif_push') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          languageProvider.isArabic ? 'Ø§Ù„Ø¥Ø´Ø¹Ø§Ø±Ø§Øª' : 'Notifications',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSwitchTile(
                    languageProvider.isArabic ? 'Ø¥Ø´Ø¹Ø§Ø±Ø§Øª Ø¹Ø§Ù…Ø©' : 'General Notifications',
                    languageProvider.isArabic ? 'Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„ØªØ­Ø¯ÙŠØ«Ø§Øª ÙˆØ§Ù„Ø¥Ø¹Ù„Ø§Ù†Ø§Øª Ø§Ù„Ù‡Ø§Ù…Ø©' : 'Receive Important Updates And Announcements',
                    _generalNotifications,
                    (v) {
                      setState(() => _generalNotifications = v);
                      _saveSetting('notif_general', v);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSwitchTile(
                    languageProvider.isArabic ? 'ØªÙ†Ø¨ÙŠÙ‡Ø§Øª ØµÙˆØªÙŠØ©' : 'Sound Alerts',
                    languageProvider.isArabic ? 'ØªÙØ¹ÙŠÙ„ Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ø§Ù„ØµÙˆØªÙŠØ© Ù„Ù„Ø¥Ø´Ø¹Ø§Ø±Ø§Øª' : 'Enable Sound Alerts For Notifications',
                    _soundAlerts,
                    (v) {
                      setState(() => _soundAlerts = v);
                      _saveSetting('notif_sound', v);
                    },
                  ),
                   const SizedBox(height: 24),
                  // Push notifications toggle is stored locally only.
                  // FCM token registration is not yet implemented.
                  // The toggle is disabled and labeled explicitly to avoid misleading the user.
                  _buildSwitchTile(
                    languageProvider.isArabic
                        ? 'Ø¥Ø´Ø¹Ø§Ø±Ø§Øª Ø§Ù„Ø¯ÙØ¹ (Ù‚Ø±ÙŠØ¨Ù‹Ø§)'
                        : 'Push Notifications (Coming Soon)',
                    languageProvider.isArabic
                        ? 'Ù‡Ø°Ø§ Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯ ØºÙŠØ± Ù…ÙØ¹Ù‘Ù„ Ø¨Ø¹Ø¯ Ø¹Ù„Ù‰ Ù…Ø³ØªÙˆÙ‰ Ø§Ù„Ø¬Ù‡Ø§Ø²'
                        : 'Stored locally only â€” device-level push not yet connected',
                    _pushNotifications,
                    null, // null disables the Switch interaction
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (onChanged == null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'COMING SOON',
                        style: TextStyle(
                          color: VSPColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: VSPColors.accent,
          activeTrackColor: VSPColors.accent.withValues(alpha: 0.3),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: VSPColors.surfaceAlt,
        ),
      ],
    );
  }
}

