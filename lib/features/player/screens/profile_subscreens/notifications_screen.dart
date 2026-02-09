import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _generalNotifications = true;
  bool _soundAlerts = true;
  bool _pushNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'General Notifications',
              'Receive Important Updates And Announcements',
              _generalNotifications,
              (v) => setState(() => _generalNotifications = v),
            ),
            const SizedBox(height: 24),
            _buildSwitchTile(
              'Sound Alerts',
              'Enable Sound Alerts For Notifications',
              _soundAlerts,
              (v) => setState(() => _soundAlerts = v),
            ),
             const SizedBox(height: 24),
            _buildSwitchTile(
              'Push Notifications',
              'Receive Push Notifications On Your Device',
              _pushNotifications,
              (v) => setState(() => _pushNotifications = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
     return Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Expanded(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 title,
                 style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 8),
               Text(
                 subtitle,
                 style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
               ),
             ],
           ),
         ),
         Switch(
           value: value,
           onChanged: onChanged,
           activeColor: AppTheme.neonGreen,
           activeTrackColor: AppTheme.neonGreen.withValues(alpha: 0.3),
           inactiveThumbColor: Colors.white,
           inactiveTrackColor: Colors.grey[800],
         ),
       ],
     );
  }
}
