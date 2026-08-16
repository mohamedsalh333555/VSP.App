import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // General (Both Roles)
  bool _generalNotifications = true;
  bool _soundAlerts = true;
  bool _chatNotifications = true;

  // Stadium Owner Toggles
  bool _ownerNewBookings = true;
  bool _ownerPayouts = true;
  bool _ownerDailySchedule = true;

  // Player Toggles
  bool _playerBookingConfirmations = true;
  bool _playerTeamTransfers = true;
  bool _playerMatchReminders = true;
  bool _playerChallengeResults = true;

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

      // Owner
      _ownerNewBookings = prefs.getBool('notif_owner_new_bookings') ?? true;
      _ownerPayouts = prefs.getBool('notif_owner_payouts') ?? true;
      _ownerDailySchedule = prefs.getBool('notif_owner_daily_schedule') ?? true;

      // Player
      _playerBookingConfirmations = prefs.getBool('notif_cash_bookings') ?? true;
      _playerTeamTransfers = prefs.getBool('notif_team_transfers') ?? true;
      _playerMatchReminders = prefs.getBool('notif_match_reminders') ?? true;
      _playerChallengeResults = prefs.getBool('notif_challenge_results') ?? true;

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
    final auth = Provider.of<AuthProvider>(context);
    final isOwner = auth.isOwner;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(isAr ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isOwner 
            ? (isAr ? 'إعدادات إشعارات الملعب' : 'Stadium Notification Settings')
            : (isAr ? 'إعدادات إشعارات اللاعب' : 'Player Notification Settings'),
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
                  // Group 1: General Settings (Both Roles)
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

                  const SizedBox(height: 28),
                  const Divider(color: VSPColors.divider, height: 1),
                  const SizedBox(height: 20),

                  // Group 2: Role Specific Preferences
                  _buildSectionHeader(
                    isOwner
                        ? (isAr ? 'تفضيلات إشعارات أصحاب الملاعب' : 'Stadium Owner Preferences')
                        : (isAr ? 'تفضيلات إشعارات اللاعبين' : 'Player Notification Preferences'),
                  ),
                  const SizedBox(height: 12),

                  // Common Chat Switch
                  _buildSwitchTile(
                    isAr ? 'رسائل الدردشة' : 'Chat Messages',
                    isOwner 
                        ? (isAr ? 'إشعار عند استلام رسائل جديدة من اللاعبين في المحادثات' : 'Alerts when receiving new messages from players')
                        : (isAr ? 'تنبيه عند استلام رسائل جديدة في محادثات التحدي أو الفريق' : 'Alerts for new messages in team or match chats'),
                    _chatNotifications,
                    _generalNotifications
                        ? (v) {
                            setState(() => _chatNotifications = v);
                            _saveSetting('notif_chat', v);
                          }
                        : null,
                  ),

                  if (isOwner) ...[
                    // STADIUM OWNER SPECIFIC TOGGLES
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'الحجوزات والطلبات الجديدة' : 'New Bookings & Requests',
                      isAr ? 'إشعار فوري عند قيام لاعب بحجز موعد جديد في ملعبك' : 'Instant alert when a player places a new booking on your pitch',
                      _ownerNewBookings,
                      _generalNotifications
                          ? (v) {
                              setState(() => _ownerNewBookings = v);
                              _saveSetting('notif_owner_new_bookings', v);
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'تنبيهات التسويات والعربون' : 'Payouts & Deposit Settlements',
                      isAr ? 'تنبيهات استلام مبالغ العربون والدفع الإلكتروني' : 'Alerts for received digital deposits and payout settlements',
                      _ownerPayouts,
                      _generalNotifications
                          ? (v) {
                              setState(() => _ownerPayouts = v);
                              _saveSetting('notif_owner_payouts', v);
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'تذكيرات جدول التشغيل اليومي' : 'Daily Schedule Reminders',
                      isAr ? 'تذكير يومي بقائمة حجوزات الملعب وساعات التشغيل' : 'Daily summary reminder of upcoming pitch bookings and schedule',
                      _ownerDailySchedule,
                      _generalNotifications
                          ? (v) {
                              setState(() => _ownerDailySchedule = v);
                              _saveSetting('notif_owner_daily_schedule', v);
                            }
                          : null,
                    ),
                  ] else ...[
                    // PLAYER SPECIFIC TOGGLES
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'تأكيدات الحجز والعربون' : 'Booking Confirmations',
                      isAr ? 'تأكيد أو تعديل موعد حجز الملعب والعربون' : 'Confirmation or status updates for your pitch bookings',
                      _playerBookingConfirmations,
                      _generalNotifications
                          ? (v) {
                              setState(() => _playerBookingConfirmations = v);
                              _saveSetting('notif_cash_bookings', v);
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'تذكيرات المباريات (قبل ساعتين)' : 'Match Reminders (2 Hours Before)',
                      isAr ? 'تذكير تلقائي على جهازك قبل بدء المباراة بساعتين' : 'Automatic reminder 2 hours before your match kickoff',
                      _playerMatchReminders,
                      _generalNotifications
                          ? (v) {
                              setState(() => _playerMatchReminders = v);
                              _saveSetting('notif_match_reminders', v);
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'الانتقالات والفرق' : 'Team & Squad Transfers',
                      isAr ? 'طلبات انضمام اللاعبين وتحديثات تشكيلة الفريق' : 'Join requests and squad roster updates',
                      _playerTeamTransfers,
                      _generalNotifications
                          ? (v) {
                              setState(() => _playerTeamTransfers = v);
                              _saveSetting('notif_team_transfers', v);
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'نتائج التحديات والترتيب' : 'Challenge Results & Ranking',
                      isAr ? 'تنبيه عند اعتماد نتيجة مباراة أو اعتراض المنافس' : 'Alert when a challenge score is submitted or disputed',
                      _playerChallengeResults,
                      _generalNotifications
                          ? (v) {
                              setState(() => _playerChallengeResults = v);
                              _saveSetting('notif_challenge_results', v);
                            }
                          : null,
                    ),
                  ],
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
