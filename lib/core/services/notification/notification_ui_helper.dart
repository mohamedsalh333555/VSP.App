import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../ui/tokens/vsp_tokens.dart';
import '../logger_service.dart';
import '../../repositories/booking_repository.dart';
import '../../../features/owner/screens/owner_bookings_screen.dart';
import '../../../features/player/screens/match_details_screen.dart';
import '../../../features/player/screens/chat_screen.dart';

/// Helper for presenting in-app notification snackbars and performing target screen navigation.
class NotificationUiHelper {
  const NotificationUiHelper._();

  /// Displays foreground in-app floating banner when not currently on the active chat screen.
  static Future<void> showInAppAlert({
    required BuildContext? context,
    required RemoteMessage message,
  }) async {
    if (context == null) return;

    final String? notifBookingId = message.data['bookingId'] ?? message.data['booking_id'];
    if (ChatScreen.activeBookingId != null &&
        (notifBookingId == ChatScreen.activeBookingId || message.data['type'] == 'chat')) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('notif_sound') ?? true;

      if (soundEnabled) {
        HapticFeedback.heavyImpact();
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Iconsax.messages_3_copy, color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.notification?.title ?? 'New Message',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      message.notification?.body ?? '',
                      style: const TextStyle(color: Colors.black, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: VSPColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      VSPLogger.e('Error showing in-app alert snackbar', e);
    }
  }

  /// Navigates to the chat screen for a given booking ID.
  static Future<void> navigateToChat(BuildContext context, String bookingId, {BookingRepository? repository}) async {
    try {
      final repo = repository ?? SupabaseBookingRepository();
      final booking = await repo.getBookingById(bookingId);
      if (booking != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(booking: booking)),
        );
      }
    } catch (e) {
      VSPLogger.e('Error navigating to chat', e);
    }
  }

  /// Navigates to the proper booking details screen based on the user role.
  static Future<void> navigateToBooking(BuildContext context, String bookingId, {BookingRepository? repository}) async {
    try {
      final repo = repository ?? SupabaseBookingRepository();
      final booking = await repo.getBookingById(bookingId);
      if (booking != null && context.mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.isOwner) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MatchDetailsScreen(bookingId: booking.id)),
          );
        }
      }
    } catch (e) {
      VSPLogger.e('Error navigating to booking', e);
    }
  }
}
