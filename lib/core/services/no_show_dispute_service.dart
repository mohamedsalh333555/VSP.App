import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safe_device/safe_device.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ui/tokens/vsp_tokens.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../repositories/notification_repository.dart';
import '../utils/vsp_feedback.dart';
import 'logger_service.dart';

/// Service managing player absence (No-Show) reporting and GPS / Geotagged selfie dispute verification.
class NoShowDisputeService {
  static NotificationRepository _notificationRepo = NotificationRepository();

  static set notificationRepo(NotificationRepository repo) {
    _notificationRepo = repo;
  }

  /// Calculates distance in meters between player position and stadium coordinates.
  static double calculateDistance({
    required double playerLat,
    required double playerLng,
    required double stadiumLat,
    required double stadiumLng,
  }) {
    return Geolocator.distanceBetween(playerLat, playerLng, stadiumLat, stadiumLng);
  }

  /// Validates if GPS accuracy meets the acceptable satellite precision threshold (<= 50m).
  static bool isAccuracyAcceptable(double accuracyMeters) {
    return accuracyMeters <= 50.0;
  }

  /// Validates if player is within the acceptable stadium proximity radius (<= 200m).
  static bool isWithinStadiumRadius(double distanceMeters) {
    return distanceMeters <= 200.0;
  }

  /// Handle reported player absence (No-Show)
  static Future<void> handleNoShowReport(
    String bookingId,
    String playerId,
    double stadiumLat,
    double stadiumLng,
  ) async {
    try {
      // 1. Call Supabase RPC 'apply_no_show_penalty' to increment the player's no-show count
      await Supabase.instance.client.rpc('apply_no_show_penalty', params: {
        'p_player_id': playerId,
      });

      // 2. Send an interactive FCM push notification to the player
      final notif = AppNotification(
        id: '',
        title: 'No-Show Warning! ',
        body: 'You were reported absent. Open the app to Dispute using GPS.',
        type: 'no_show_warning',
        bookingId: bookingId,
        createdAt: DateTime.now(),
        metadata: {
          'stadiumLat': stadiumLat,
          'stadiumLng': stadiumLng,
          'playerId': playerId,
        },
      );
      await _notificationRepo.sendNotification(playerId, notif);
      VSPLogger.i('No-show penalty applied and notification sent to player $playerId.');
    } catch (e) {
      VSPLogger.e('Error applying no-show report: $e');
    }
  }

  /// Dispute a no-show report on player's device using GPS location and SafeDevice spoofing checks
  static Future<bool> disputeNoShowWithGPS({
    required String bookingId,
    required String playerId,
    required double stadiumLat,
    required double stadiumLng,
  }) async {
    try {
      // 1. Security Check: SafeDevice checks
      try {
        final bool isJailBroken = await SafeDevice.isJailBroken.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            VSPLogger.w("SafeDevice jailbreak check timed out in dispute handler.");
            return false;
          },
        );
        final bool isMockLocation = await SafeDevice.isMockLocation.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            VSPLogger.w("SafeDevice mock location check timed out in dispute handler.");
            return false;
          },
        );
        if (isJailBroken || isMockLocation) {
          VSPLogger.w("Device Security Alert: Jailbroken=$isJailBroken, MockLocation=$isMockLocation");
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            VSPFeedback.showError(context, 'فشل التحقق: تم كشف التلاعب بالموقع الجغرافي! ');
          }
          return false;
        }
      } catch (e) {
        VSPLogger.e("Error performing safe device checks: $e");
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          VSPFeedback.showError(context, 'فشل التحقق بسبب خطأ أمني! ');
        }
        return false;
      }

      // 2. Fetch player's current location using Geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            VSPFeedback.showError(context, 'يرجى إعطاء صلاحية الموقع الجغرافي لتقديم النزاع. ');
          }
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          VSPFeedback.showError(context, 'صلاحية الموقع الجغرافي معطلة تماماً. يرجى تفعيلها من الإعدادات. ');
        }
        return false;
      }

      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        VSPLogger.w('Failed to get current position for no-show dispute: $e');
      }

      if (position == null) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          VSPFeedback.showError(context, 'تعذر تحديد موقعك الحالي. يرجى التحقق من اتصال الـ GPS. ');
        }
        return false;
      }

      // SECURITY BARRIER: GPS Accuracy Gate
      if (!isAccuracyAcceptable(position.accuracy)) {
        VSPLogger.w('GPS dispute rejected: Accuracy too low (${position.accuracy.toStringAsFixed(1)}m > 50m threshold)');
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final useSelfie = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: VSPColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
              title: const Row(
                children: [
                  Icon(Iconsax.location_slash_copy, color: VSPColors.warning),
                  SizedBox(width: 8),
                  Text('دقة الـ GPS ضعيفة ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'دقة إشارة الـ GPS الحالية هي (${position!.accuracy.toStringAsFixed(0)} متر) وهي أكبر من الحد المسموح به (50 متراً) بسبب حجب سقف الملعب المغطى.\n\nهل ترغب في رفع صورة سيلفي موثقة جغرافياً (Geotagged Selfie) كخيار بديل لتأكيد تواجدك؟',
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء', style: TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('استخدام سيلفي جغرافية', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );

          if (useSelfie == true) {
            try {
              final ImagePicker picker = ImagePicker();
              final XFile? selfieFile = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 75,
              );
              if (selfieFile == null) {
                if (context.mounted) {
                  VSPFeedback.showError(context, 'تم إلغاء التقاط صورة السيلفي. ');
                }
                return false;
              }

              final bytes = await selfieFile.readAsBytes();
              final storagePath = 'disputes/selfie_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
              await Supabase.instance.client.storage
                  .from('owner_documents')
                  .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
              final publicUrl = Supabase.instance.client.storage
                  .from('owner_documents')
                  .getPublicUrl(storagePath);

              final bool selfieSuccess = await disputeWithGeotaggedSelfie(
                bookingId: bookingId,
                playerId: playerId,
                photoUrl: publicUrl,
                stadiumLat: stadiumLat,
                stadiumLng: stadiumLng,
              );

              if (selfieSuccess) {
                VSPFeedback.triggerSuccess();
                if (context.mounted) {
                  VSPFeedback.showSuccess(context, 'تم قبول النزاع وإلغاء العقوبة بنجاح عبر الصورة الموثقة! ');
                }
                return true;
              } else {
                if (context.mounted) {
                  VSPFeedback.showError(context, 'فشل التحقق من بيانات الصورة الموثقة. ');
                }
                return false;
              }
            } catch (e) {
              VSPLogger.e("Error capturing geotagged selfie: $e");
              if (context.mounted) {
                VSPFeedback.showError(context, 'فشل التقاط صورة السيلفي. ');
              }
              return false;
            }
          }
        }
        return false;
      }

      // 3. Invoke the secured Supabase RPC dispute function
      try {
        final bool success = await Supabase.instance.client.rpc('dispute_no_show_with_gps', params: {
          'p_booking_id': bookingId,
          'p_player_id': playerId,
          'p_lat': position.latitude,
          'p_lng': position.longitude,
          'p_accuracy': position.accuracy,
        });

        if (success) {
          VSPLogger.i('No-show penalty successfully dismissed via GPS database verification.');
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            VSPFeedback.triggerSuccess();
            const msgAr = 'تم قبول النزاع وإلغاء العقوبة بنجاح! ';
            VSPFeedback.showSuccess(context, msgAr);
          }
          return true;
        } else {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            const msgAr = 'فشل النزاع: لم يتم التحقق من موقعك.';
            VSPFeedback.showError(context, msgAr);
          }
          return false;
        }
      } on PostgrestException catch (e) {
        VSPLogger.e('Database error during GPS dispute: ${e.message}');
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final String errorMsg = e.message.toLowerCase();
          if (errorMsg.contains('dispute_window_expired')) {
            VSPFeedback.showError(
              context,
              'عذراً، انتهت المهلة الزمنية لتقديم النزاع! كان يجب تقديم النزاع خلال ساعة واحدة كحد أقصى من نهاية وقت المباراة.',
            );
          } else if (errorMsg.contains('not_at_stadium')) {
            VSPFeedback.showError(
              context,
              'فشل النزاع: أنت لست متواجداً في محيط الملعب حالياً! يرجى تفعيل الـ GPS والتواجد في أرضية الملعب للمحاولة.',
            );
          } else if (errorMsg.contains('stadium_coordinates_missing')) {
            VSPFeedback.showError(
              context,
              'إحداثيات الملعب الجغرافية غير مسجلة بالنظام. يرجى تقديم صورة سيلفي موثقة جغرافياً (Geotagged Selfie) أو التواصل مع الدعم الفني. ',
            );
          } else if (errorMsg.contains('booking_not_found')) {
            VSPFeedback.showError(
              context,
              'هذا الحجز غير مسجل في النظام.',
            );
          } else {
            VSPFeedback.showError(context, e.message);
          }
        }
        return false;
      } catch (e) {
        VSPLogger.e('Unexpected error during GPS dispute: $e');
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          VSPFeedback.showError(context, e.toString());
        }
        return false;
      }
    } catch (e) {
      VSPLogger.e('Error disputing no-show with GPS: $e');
      return false;
    }
  }

  /// Handles geotagged selfie evidence dispute submissions.
  static Future<bool> disputeWithGeotaggedSelfie({
    required String bookingId,
    required String playerId,
    required String photoUrl,
    required double stadiumLat,
    required double stadiumLng,
  }) async {
    try {
      Position currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final double distanceMeters = calculateDistance(
        playerLat: currentPos.latitude,
        playerLng: currentPos.longitude,
        stadiumLat: stadiumLat,
        stadiumLng: stadiumLng,
      );

      // Verify distance threshold (must be within 200m of stadium)
      if (!isWithinStadiumRadius(distanceMeters)) {
        VSPLogger.w('Dispute rejected: Player too far from stadium during selfie (${distanceMeters.toStringAsFixed(1)} m)');
        return false;
      }

      // Record verified dispute report in Supabase
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': playerId,
        'target_id': bookingId,
        'target_type': 'no_show_dispute',
        'reason': 'Geotagged Selfie Dispute',
        'details': 'Verified distance: ${distanceMeters.toStringAsFixed(1)}m. Lat: ${currentPos.latitude}, Lng: ${currentPos.longitude}. Photo: $photoUrl',
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await Supabase.instance.client.from('bookings').update({
        'dispute_photo_url': photoUrl,
        'match_result_status': 'disputed',
        'requires_admin_intervention': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);

      VSPLogger.i('Verified Geotagged selfie dispute submitted (${distanceMeters.toStringAsFixed(1)} m from pitch).');
      return true;
    } catch (e) {
      VSPLogger.e('Error in secure selfie dispute', e);
      return false;
    }
  }
}
