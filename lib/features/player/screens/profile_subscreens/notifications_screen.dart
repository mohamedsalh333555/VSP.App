import 'package:flutter/material.dart';
import '../../../../core/ui/vsp_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/vsp_back_button.dart';

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
  bool _settingsLoadFailed = false;
  String? _settingsUserId;

  // Reset synchronously on account switch, even if the next account's
  // SharedPreferences read throws. Never show previous user's toggles.
  void _resetNotificationSettings() {
    _generalNotifications = true;
    _soundAlerts = true;
    _chatNotifications = true;
    _ownerNewBookings = true;
    _ownerPayouts = true;
    _ownerDailySchedule = true;
    _playerBookingConfirmations = true;
    _playerTeamTransfers = true;
    _playerMatchReminders = true;
    _playerChallengeResults = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<AuthProvider>().currentUser?.id ?? '';
    if (_settingsUserId != userId) {
      _settingsUserId = userId;
      _resetNotificationSettings();
      _settingsLoadFailed = false;
      _isLoading = true;
      _loadSettings(userId);
    }
  }

  // Preferences are per account. Never import the old unscoped keys: they
  // could belong to a different user of the same shared device.
  String _prefKey(String userId, String key) => 'vsp_user_${userId}_$key';

  Future<void> _loadSettings(String userId) async {
    if (userId.isEmpty) {
      if (!mounted || _settingsUserId != userId) return;
      // didChangeDependencies already triggers a build. Do not call setState
      // synchronously from that lifecycle when the account signs out.
      _resetNotificationSettings();
      _settingsLoadFailed = false;
      _isLoading = false;
      return;
    }
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Never show default/old-account toggles as if they were persisted
      // when the local preference store is unavailable.
      if (!mounted || _settingsUserId != userId) return;
      _settingsLoadFailed = true;
      setState(() => _isLoading = false);
      return;
    }
    // A slow read for the previous account must not overwrite the next
    // account's settings after logout or account switching.
    if (!mounted || _settingsUserId != userId) return;
    bool read(String key) => prefs.getBool(_prefKey(userId, key)) ?? true;
    setState(() {
      _settingsLoadFailed = false;
      _generalNotifications = read('notif_general');
      _soundAlerts = read('notif_sound');
      _chatNotifications = read('notif_chat');
      _ownerNewBookings = read('notif_owner_new_bookings');
      _ownerPayouts = read('notif_owner_payouts');
      _ownerDailySchedule = read('notif_owner_daily_schedule');
      _playerBookingConfirmations = read('notif_cash_bookings');
      _playerTeamTransfers = read('notif_team_transfers');
      _playerMatchReminders = read('notif_match_reminders');
      _playerChallengeResults = read('notif_challenge_results');
      _isLoading = false;
    });
  }

  Future<bool> _saveSetting(String key, bool value) async {
    final userId = _settingsUserId;
    if (userId == null || userId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Do not persist a delayed toggle under a different account.
      if (!mounted || _settingsUserId != userId) return false;
      final saved = await prefs.setBool(_prefKey(userId, key), value);
      if (!saved && mounted && _settingsUserId == userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'تعذر حفظ تفضيل الإشعارات.'
                : 'Could not save notification preference.',
          )),
        );
      }
      return saved;
    } catch (_) {
      if (!mounted || _settingsUserId != userId) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'تعذر حفظ تفضيل الإشعارات.'
              : 'Could not save notification preference.',
        )),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isAr = languageProvider.isArabic;
    final auth = Provider.of<AuthProvider>(context);
    final isOwner = auth.isOwner;

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        title: Text(
          isOwner 
            ? (isAr ? 'إعدادات إشعارات الملعب' : 'Stadium Notification Settings')
            : (isAr ? 'إعدادات إشعارات اللاعب' : 'Player Notification Settings'),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? VSPStateView(
                state: VSPUiState.loading,
                title: Localizations.localeOf(context).languageCode == 'ar' ? 'جارٍ تحميل الإشعارات' : 'Loading notifications',
                message: Localizations.localeOf(context).languageCode == 'ar' ? 'نحدّث تفضيلات الإشعارات.' : 'Fetching notification preferences.',
              )
            : _settingsLoadFailed
                ? VSPStateView(
                    state: VSPUiState.error,
                    title: isAr
                        ? 'تعذر تحميل إعدادات الإشعارات'
                        : 'Could not load notification preferences',
                    message: isAr
                        ? 'لم نقدر نتحقق من الإعدادات المحفوظة لهذا الحساب. جرّب مرة تانية.'
                        : 'Saved settings for this account could not be verified. Please retry.',
                    onRetry: () {
                      final userId = _settingsUserId;
                      if (!mounted || userId == null || userId.isEmpty) return;
                      setState(() {
                        _isLoading = true;
                        _settingsLoadFailed = false;
                      });
                      _loadSettings(userId);
                    },
                  )
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
                    (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_general', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _generalNotifications = v);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSwitchTile(
                    isAr ? 'تنبيهات صوتية' : 'Sound Alerts',
                    isAr ? 'تفعيل التنبيهات الصوتية للإشعارات' : 'Enable sound alerts for notifications',
                    _soundAlerts,
                    (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_sound', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _soundAlerts = v);
                      }
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
                        ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_chat', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _chatNotifications = v);
                      }
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
                          ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_owner_new_bookings', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _ownerNewBookings = v);
                      }
                    }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'تنبيهات التسويات والعربون' : 'Payouts & Deposit Settlements',
                      isAr ? 'تنبيهات استلام مبالغ العربون والدفع الإلكتروني' : 'Alerts for received digital deposits and payout settlements',
                      _ownerPayouts,
                      _generalNotifications
                          ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_owner_payouts', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _ownerPayouts = v);
                      }
                    }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'تذكيرات جدول التشغيل اليومي' : 'Daily Schedule Reminders',
                      isAr ? 'تذكير يومي بقائمة حجوزات الملعب وساعات التشغيل' : 'Daily summary reminder of upcoming pitch bookings and schedule',
                      _ownerDailySchedule,
                      _generalNotifications
                          ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_owner_daily_schedule', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _ownerDailySchedule = v);
                      }
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
                          ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_cash_bookings', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _playerBookingConfirmations = v);
                      }
                    }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'تذكيرات المباريات (قبل ساعتين)' : 'Match Reminders (2 Hours Before)',
                      isAr ? 'تذكير تلقائي على جهازك قبل بدء المباراة بساعتين' : 'Automatic reminder 2 hours before your match kickoff',
                      _playerMatchReminders,
                      _generalNotifications
                          ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_match_reminders', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _playerMatchReminders = v);
                      }
                    }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'الانتقالات والفرق' : 'Team & Squad Transfers',
                      isAr ? 'طلبات انضمام اللاعبين وتحديثات تشكيلة الفريق' : 'Join requests and squad roster updates',
                      _playerTeamTransfers,
                      _generalNotifications
                          ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_team_transfers', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _playerTeamTransfers = v);
                      }
                    }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      isAr ? 'نتائج التحديات والترتيب' : 'Challenge Results & Ranking',
                      isAr ? 'تنبيه عند اعتماد نتيجة مباراة أو اعتراض المنافس' : 'Alert when a challenge score is submitted or disputed',
                      _playerChallengeResults,
                      _generalNotifications
                          ? (v) async {
                      // Commit first: a failed local preference write must not
                      // leave a misleading enabled/disabled switch on screen.
                      final requestUserId = _settingsUserId;
                      if (await _saveSetting('notif_challenge_results', v) &&
                          mounted && _settingsUserId == requestUserId) {
                        setState(() => _playerChallengeResults = v);
                      }
                    }
                          : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
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
          inactiveThumbColor: VSPColors.white.withValues(alpha: 0.8),
          inactiveTrackColor: VSPColors.surfaceAlt,
        ),
      ],
    );
  }
}
