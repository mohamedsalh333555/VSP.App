import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  // General
  bool _generalNotifications = true;
  bool _soundAlerts = true;

  // Granular Toggles
  bool _chatNotifications = true;
  bool _cashBookings = true;
  bool _teamTransfers = true;
  bool _matchReminders = true;
  bool _challengeResults = true;

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

      _chatNotifications = prefs.getBool('notif_chat') ?? true;
      _cashBookings = prefs.getBool('notif_cash_bookings') ?? true;
      _teamTransfers = prefs.getBool('notif_team_transfers') ?? true;
      _matchReminders = prefs.getBool('notif_match_reminders') ?? true;
      _challengeResults = prefs.getBool('notif_challenge_results') ?? true;

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
    final isAr = languageProvider.isArabic;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? 'إعدادات الإشعارات' : 'Notification Settings',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group 1: General Settings
                  _buildSectionHeader(isAr ? 'إعدادات عامة' : 'General Settings'),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    isAr ? 'إشعارات عامة' : 'General Notifications',
                    isAr ? 'تلقي التحديثات والإعلانات الهامة' : 'Receive important updates and announcements',
                    _generalNotifications,
                    (v) {
                      setState(() => _generalNotifications = v);
                      _saveSetting('notif_general', v);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSwitchTile(
                    isAr ? 'تنبيهات صوتية' : 'Sound Alerts',
                    isAr ? 'تفعيل التنبيهات الصوتية للإشعارات' : 'Enable sound alerts for notifications',
                    _soundAlerts,
                    (v) {
                      setState(() => _soundAlerts = v);
                      _saveSetting('notif_sound', v);
                    },
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: VSPColors.divider, height: 1),
                  const SizedBox(height: 24),

                  // Group 2: Specific Alerts
                  _buildSectionHeader(isAr ? 'تفاصيل التنبيهات' : 'Notification Preferences'),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    isAr ? 'إشعارات الدردشة' : 'Chat Notifications',
                    isAr ? 'تنبيهات عند استلام رسائل جديدة في المحادثات' : 'Alerts when receiving new messages in chat',
                    _chatNotifications,
                    _generalNotifications
                        ? (v) {
                            setState(() => _chatNotifications = v);
                            _saveSetting('notif_chat', v);
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildSwitchTile(
                    isAr ? 'تأكيدات الحجز النقدي' : 'Cash Booking Confirmations',
                    isAr ? 'تنبيه عند قبول أو رفض المالك للحجز النقدي' : 'Notification when owner confirms or rejects a cash booking',
                    _cashBookings,
                    _generalNotifications
                        ? (v) {
                            setState(() => _cashBookings = v);
                            _saveSetting('notif_cash_bookings', v);
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildSwitchTile(
                    isAr ? 'الانتقالات والفرق' : 'Team & Transfers',
                    isAr ? 'طلبات الانضمام وتغييرات قائمة الفريق' : 'Join requests and squad roster updates',
                    _teamTransfers,
                    _generalNotifications
                        ? (v) {
                            setState(() => _teamTransfers = v);
                            _saveSetting('notif_team_transfers', v);
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildSwitchTile(
                    isAr ? 'تذكيرات المباريات' : 'Match Reminders',
                    isAr ? 'تذكير تلقائي على جهازك قبل بدء المباراة بساعتين' : 'Automatic reminder on your device 2 hours before kickoff',
                    _matchReminders,
                    _generalNotifications
                        ? (v) {
                            setState(() => _matchReminders = v);
                            _saveSetting('notif_match_reminders', v);
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildSwitchTile(
                    isAr ? 'نتائج التحديات' : 'Challenge Match Results',
                    isAr ? 'تنبيه عند إرسال نتيجة مباراة أو الاعتراض عليها' : 'Alert when a challenge score is submitted or disputed',
                    _challengeResults,
                    _generalNotifications
                        ? (v) {
                            setState(() => _challengeResults = v);
                            _saveSetting('notif_challenge_results', v);
                          }
                        : null,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: VSPColors.accent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    final isEnabled = onChanged != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isEnabled ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isEnabled ? VSPColors.textSecondary : VSPColors.textSecondary.withValues(alpha: 0.3),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(
          value: isEnabled ? value : false,
          onChanged: onChanged,
          activeColor: VSPColors.accent,
          activeTrackColor: VSPColors.accent.withValues(alpha: 0.3),
          inactiveThumbColor: Colors.white.withValues(alpha: 0.8),
          inactiveTrackColor: VSPColors.surfaceAlt,
        ),
      ],
    );
  }
}
