import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../ui/tokens/vsp_tokens.dart';

class VSPFeedback {

 // ─── نظام الألوان الموحد للتنبيهات اللحظية ───
 // أخضر = نجاح (VSPColors.accent)
 // أحمر = خطأ (VSPColors.error)
 // برتقالي = تحذير (VSPColors.warning / Orange)
 // أبيض = معلومة (Colors.white / textPrimary)

 /// نجاح
 static void showSuccess(BuildContext context, String message) {
 HapticFeedback.lightImpact();
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: VSPColors.accent,
 textColor: Colors.black,
 icon: Iconsax.tick_circle_copy,
 );
 }

 /// خطأ — مع تنظيف تلقائي للرسالة من prefixes الـ DB
 static void showError(BuildContext context, String rawMessage) {
 HapticFeedback.heavyImpact();
 final message = _cleanErrorMessage(context, rawMessage);
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: VSPColors.error,
 textColor: Colors.white,
 icon: Iconsax.warning_2_copy,
 );
 }

 /// تحذير
 static void showWarning(BuildContext context, String message) {
 HapticFeedback.mediumImpact();
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: const Color(0xFFE67E22),
 textColor: Colors.white,
 icon: Iconsax.warning_2_copy,
 );
 }

 /// معلومة
 static void showInfo(BuildContext context, String message) {
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: VSPColors.surface,
 textColor: Colors.white,
 icon: Iconsax.info_circle_copy,
 );
 }

 static void triggerSuccess() {
 HapticFeedback.lightImpact();
 }

 static void triggerTap() {
 HapticFeedback.selectionClick();
 }

 /// تنظيف رسائل الخطأ الخام من DB ومع localization تلقائي
 static String _cleanErrorMessage(BuildContext context, String raw) {
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 String msg = raw
 .replaceAll('Failed to create booking: ', '')
 .replaceAll('Exception: ', '')
 .replaceAll('PostgrestException', '')
 .replaceAll('(message:', '')
 .replaceAll('hint: null)', '')
 .trim();

 // ترجمة رسائل double booking الشائعة
 if (msg.contains('double booking') || msg.contains('time_conflict') || msg.contains('تحجز نفس الوقت')) {
 return isAr
 ? 'هذا الوقت محجوز بالفعل. يرجى اختيار وقت آخر.'
 : 'This time slot is already booked. Please choose another.';
 }
 if (msg.contains('cash limit') || msg.contains('حد الكاش')) {
 return isAr
 ? 'تجاوزت حد الحجوزات النقدية المسموح بها. يرجى سداد الحجوزات السابقة أولاً.'
 : 'Cash booking limit reached. Please pay for previous bookings first.';
 }

 return msg.isNotEmpty ? msg : (isAr ? 'حدث خطأ غير متوقع.' : 'An unexpected error occurred.');
 }

 /// المحرك المركزي لإظهار التنبيهات بـ Root Overlay فوق جميع الطبقات والبوب اب
 static void _showOverlayToast({
 required BuildContext context,
 required String message,
 required Color backgroundColor,
 required Color textColor,
 required IconData icon,
 }) {
 try {
 final overlay = Overlay.of(context, rootOverlay: true);
 late OverlayEntry entry;

 entry = OverlayEntry(
 builder: (ctx) => Positioned(
 top: MediaQuery.of(ctx).padding.top + 12,
 left: 16,
 right: 16,
 child: Material(
 color: Colors.transparent,
 child: TweenAnimationBuilder<double>(
 tween: Tween(begin: 0.0, end: 1.0),
 duration: const Duration(milliseconds: 250),
 curve: Curves.easeOutBack,
 builder: (ctx, value, child) {
 return Transform.translate(
 offset: Offset(0, (1 - value) * -20),
 child: Opacity(
 opacity: value.clamp(0.0, 1.0),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: backgroundColor,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 boxShadow: const [
 BoxShadow(
 color: Colors.black38,
 blurRadius: 12,
 offset: Offset(0, 4),
 )
 ],
 ),
 child: Row(
 children: [
 Icon(icon, color: textColor, size: 20),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 message,
 style: TextStyle(
 color: textColor,
 fontWeight: FontWeight.bold,
 fontSize: 13,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 },
 ),
 ),
 ),
 );

 // إدراج التنبيه في أعلى طبقة بالـ Navigator
 overlay.insert(entry);

 // إخفاء التنبيه أوتوماتيكياً بعد 3 ثوانٍ
 Future.delayed(const Duration(seconds: 3), () {
 if (entry.mounted) {
 entry.remove();
 }
 });
 } catch (e) {
 // السقوط الخلفي للـ SnackBar الإعتيادي في حال عدم توفر Overlay
 ScaffoldMessenger.of(context).hideCurrentSnackBar();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(message, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
 backgroundColor: backgroundColor,
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
  }

  /// تتبع التنبيه النشط للتراجع لمنع التداخل
  static OverlayEntry? _activeUndoEntry;

  /// إظهار شريط التراجع التفاعلي (Undo Bar) مع مؤقت تنازلي مدته 5 ثوانٍ
  /// مخصص للعمليات الحساسة (مثل إلغاء حجز، مغادرة فريق، حذف موعد)
  static void showUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    VoidCallback? onTimeout,
    Duration duration = const Duration(seconds: 5),
    String? undoLabel,
    IconData? icon,
    bool atBottom = true,
  }) {
    HapticFeedback.lightImpact();

    // إغلاق أي تنبيه تراجع سابق ما زال معروضاً
    if (_activeUndoEntry != null && _activeUndoEntry!.mounted) {
      try {
        _activeUndoEntry!.remove();
      } catch (_) {}
      _activeUndoEntry = null;
    }

    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      late OverlayEntry entry;

      void dismiss() {
        if (entry.mounted) {
          entry.remove();
          if (_activeUndoEntry == entry) {
            _activeUndoEntry = null;
          }
        }
      }

      entry = OverlayEntry(
        builder: (ctx) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom > 0
              ? MediaQuery.of(ctx).viewInsets.bottom + 16
              : MediaQuery.of(ctx).padding.bottom + 20;

          return Positioned(
            bottom: atBottom ? bottomPadding : null,
            top: atBottom ? null : (MediaQuery.of(ctx).padding.top + 12),
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: _VSPUndoToastWidget(
                message: message,
                undoLabel: undoLabel,
                duration: duration,
                icon: icon,
                onUndo: onUndo,
                onTimeout: onTimeout,
                onDismiss: dismiss,
              ),
            ),
          );
        },
      );

      _activeUndoEntry = entry;
      overlay.insert(entry);
    } catch (e) {
      // السقوط الخلفي للـ SnackBar الإعتيادي في حال عدم توفر Overlay
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          backgroundColor: VSPColors.surfaceAlt,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: undoLabel ?? (Localizations.localeOf(context).languageCode == 'ar' ? 'تراجع' : 'Undo'),
            textColor: VSPColors.accent,
            onPressed: onUndo,
          ),
        ),
      );
    }
  }
}

/// ويدجت داخلي مخصص لشريط التراجع التفاعلي مع شريط مؤقت متناقص وزر متوهج
class _VSPUndoToastWidget extends StatefulWidget {
  final String message;
  final String? undoLabel;
  final Duration duration;
  final IconData? icon;
  final VoidCallback onUndo;
  final VoidCallback? onTimeout;
  final VoidCallback onDismiss;

  const _VSPUndoToastWidget({
    required this.message,
    this.undoLabel,
    required this.duration,
    this.icon,
    required this.onUndo,
    this.onTimeout,
    required this.onDismiss,
  });

  @override
  State<_VSPUndoToastWidget> createState() => _VSPUndoToastWidgetState();
}

class _VSPUndoToastWidgetState extends State<_VSPUndoToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  bool _isHandled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isHandled) {
        _isHandled = true;
        widget.onTimeout?.call();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleUndo() {
    if (_isHandled) return;
    _isHandled = true;
    HapticFeedback.mediumImpact();
    widget.onUndo();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final label = widget.undoLabel ?? (isAr ? 'تراجع' : 'Undo');

    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, child) {
        return Transform.translate(
          offset: Offset(0, (1.0 - _slideAnimation.value) * 25),
          child: Opacity(
            opacity: _slideAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    widget.icon ?? Icons.undo_rounded,
                    color: VSPColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleUndo,
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: VSPColors.accent,
                          borderRadius: BorderRadius.circular(VSPRadius.sm),
                          boxShadow: [
                            BoxShadow(
                              color: VSPColors.accent.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final progress = (1.0 - _controller.value);
                            final seconds = (widget.duration.inSeconds * progress).ceil().clamp(1, widget.duration.inSeconds);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$label ($seconds)',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // شريط المؤقت التنازلي المنساب في أسفل الكبسولة
            AnimatedBuilder(
              animation: _controller,
              builder: (ctx, _) {
                return LinearProgressIndicator(
                  value: 1.0 - _controller.value,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
                  minHeight: 2.5,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
