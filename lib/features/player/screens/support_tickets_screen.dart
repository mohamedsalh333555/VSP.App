import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/ui/vsp_ui.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../data/models.dart';
import 'support_ticket_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  final String? initialCategory;
  final Booking? contextBooking;

  const SupportTicketsScreen({
    super.key,
    this.initialCategory,
    this.contextBooking,
  });

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final ChatRepository _repo = ChatRepository();
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  String _streamUserId = '';

  @override
  void initState() {
    super.initState();
    _streamUserId = context.read<AuthProvider>().currentUser?.id ?? '';
    _ticketsStream = _repo.streamSupportTickets(_streamUserId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeUserId = context.watch<AuthProvider>().currentUser?.id ?? '';
    if (activeUserId != _streamUserId) {
      _streamUserId = activeUserId;
      _ticketsStream = _repo.streamSupportTickets(activeUserId);
    }
  }

  Future<void> _newTicket() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final subjectController = TextEditingController();
    String category = widget.initialCategory ?? 'general';
    bool isSubmitting = false;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Prevent accidental dismissal while a ticket is being created.
      // An explicit Cancel action remains available before submission.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ConstrainedBox(
          constraints: BoxConstraints(
            // The modal already applies the keyboard inset, while useSafeArea
          // protects the system bars. Subtracting those insets again here
          // double-counts them and can collapse the usable sheet viewport.
          maxHeight: (MediaQuery.sizeOf(ctx).height -
                    MediaQuery.viewInsetsOf(ctx).bottom -
                    VSPSpacing.xxl)
                .clamp(0.0, MediaQuery.sizeOf(ctx).height)
                .toDouble(),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              VSPSpacing.lg,
              VSPSpacing.lg,
              VSPSpacing.lg,
              MediaQuery.paddingOf(ctx).bottom + VSPSpacing.lg,
            ),
            child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(
                isArabic ? 'فتح تذكرة دعم' : 'Open Support Ticket',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: VSPSpacing.md),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'عنوان المشكلة' : 'Issue subject',
                  hintText: isArabic ? 'مثال: مشكلة في الدفع' : 'Example: Payment issue',
                ),
              ),
              const SizedBox(height: VSPSpacing.md),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(labelText: isArabic ? 'التصنيف' : 'Category'),
                items: [
                  DropdownMenuItem(value: 'account', child: Text(isArabic ? 'الحساب' : 'Account')),
                  DropdownMenuItem(value: 'booking', child: Text(isArabic ? 'الحجز' : 'Booking')),
                  DropdownMenuItem(value: 'payment', child: Text(isArabic ? 'الدفع' : 'Payment')),
                  DropdownMenuItem(value: 'refund', child: Text(isArabic ? 'الاسترداد' : 'Refund')),
                  DropdownMenuItem(value: 'tournament', child: Text(isArabic ? 'البطولات' : 'Tournament')),
                  DropdownMenuItem(value: 'report', child: Text(isArabic ? 'بلاغ' : 'Report')),
                  DropdownMenuItem(value: 'technical', child: Text(isArabic ? 'مشكلة تقنية' : 'Technical')),
                  DropdownMenuItem(value: 'general', child: Text(isArabic ? 'عام' : 'General')),
                ],
                onChanged: (v) => setSheetState(() => category = v ?? category),
              ),
              const SizedBox(height: VSPSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final subject = subjectController.text.trim();
                          if (subject.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(isArabic ? 'اكتب عنوان المشكلة أولاً.' : 'Enter an issue subject first.')),
                            );
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          try {
                            final booking = widget.contextBooking;
                            final ticket = await _repo.createSupportTicket(
                              subject: subject,
                              category: category,
                              contextType: booking == null ? null : 'booking',
                              contextId: booking?.id,
                              bookingId: booking?.id,
                              priority: category == 'refund' || category == 'payment' ? 'high' : 'normal',
                            );
                            if (ctx.mounted) Navigator.pop(ctx, ticket['id']?.toString());
                          } catch (e) {
                            VSPLogger.w('Support ticket creation failed: $e');
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(isArabic ? 'تعذر فتح التذكرة.' : 'Could not create the ticket.')),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setSheetState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(isArabic ? 'فتح التذكرة' : 'Open Ticket'),
                    ),
                  ),
                ],
              ),
              ],
            ),
            ),
          ),
        ),
      ),
    );

    final submittedSubject = subjectController.text.trim();
    subjectController.dispose();

    if (result != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportTicketScreen(ticketId: result, title: submittedSubject),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(isArabic ? 'تذاكر الدعم' : 'Support Tickets'),
      ),
      body: userId.isEmpty
          ? VSPEmptyState(
              icon: Iconsax.warning_2_copy,
              title: isArabic ? 'سجّل الدخول أولاً' : 'Please sign in',
              subtitle: isArabic ? 'يجب تسجيل الدخول لاستخدام الدعم داخل التطبيق.' : 'Sign in to use in-app support.',
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(userId),
              stream: _ticketsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }
                if (snapshot.hasError &&
                    (snapshot.data == null || snapshot.data!.isEmpty)) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(VSPSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 32),
                          const SizedBox(height: VSPSpacing.md),
                          Text(
                            isArabic ? 'تعذر تحميل تذاكر الدعم.' : 'Could not load support tickets.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: VSPColors.textSecondary),
                          ),
                          const SizedBox(height: VSPSpacing.md),
                          TextButton(
                            onPressed: () => setState(() {
                              _ticketsStream = _repo.streamSupportTickets(userId);
                            }),
                            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final tickets = snapshot.data ?? [];
                if (tickets.isEmpty && !snapshot.hasError) {
                  return VSPEmptyState(
                    icon: Iconsax.messages_3_copy,
                    title: isArabic ? 'لا توجد تذاكر دعم' : 'No support tickets',
                    subtitle: userId.isEmpty
                        ? (isArabic
                            ? 'سجّل الدخول لعرض تذاكر الدعم أو إنشاء تذكرة جديدة.'
                            : 'Sign in to view your support tickets or create a new one.')
                        : (isArabic
                            ? 'افتح تذكرة وسيقوم فريق VSP بمتابعتها هنا.'
                            : 'Open a ticket and the VSP team will follow it here.'),
                    buttonText: userId.isEmpty
                        ? null
                        : (isArabic ? 'فتح تذكرة' : 'Open Ticket'),
                    onButtonPressed: userId.isEmpty ? null : _newTicket,
                  );
                }
                return Column(
                  children: [
                    if (snapshot.hasError)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(
                          VSPSpacing.md,
                          VSPSpacing.sm,
                          VSPSpacing.md,
                          0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: VSPSpacing.md,
                          vertical: VSPSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(
                            color: VSPColors.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Iconsax.warning_2_copy,
                              color: VSPColors.warning,
                              size: 17,
                            ),
                            const SizedBox(width: VSPSpacing.sm),
                            Expanded(
                              child: Text(
                                isArabic
                                    ? 'تعذر تحديث التذاكر. نعرض آخر بيانات تم تحميلها.'
                                    : 'Could not refresh tickets. Showing the last loaded data.',
                                style: const TextStyle(
                                  color: VSPColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _ticketsStream = _repo.streamSupportTickets(userId);
                              }),
                              child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: VSPScrollPadding.forList(
                          context,
                          hasFloatingNavBar: true,
                        ),
                        itemCount: tickets.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: VSPSpacing.sm),
                        itemBuilder: (context, index) {
                          final ticket = tickets[index];
                          final status =
                              ticket['status']?.toString().toLowerCase() ?? 'open';
                          final statusLabel = switch (status) {
                            'in_progress' =>
                              isArabic ? 'قيد المتابعة' : 'In progress',
                            'waiting_user' =>
                              isArabic ? 'في انتظار ردك' : 'Waiting for you',
                            'resolved' => isArabic ? 'تم الحل' : 'Resolved',
                            'closed' => isArabic ? 'مغلقة' : 'Closed',
                            _ => isArabic ? 'مفتوحة' : 'Open',
                          };
                          final title = ticket['subject']?.toString() ??
                              (isArabic ? 'تذكرة دعم' : 'Support Ticket');
                          return ListTile(
                            tileColor: VSPColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.card),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              isArabic
                                  ? 'الحالة: $statusLabel'
                                  : 'Status: $statusLabel',
                              style: const TextStyle(color: VSPColors.textSecondary),
                            ),
                            trailing: const Icon(
                              Iconsax.arrow_right_3_copy,
                              color: VSPColors.textSecondary,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SupportTicketScreen(
                                  ticketId: ticket['id'].toString(),
                                  title: title,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: userId.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _newTicket,
              backgroundColor: VSPColors.accent,
              child: const Icon(Iconsax.add_copy, color: Colors.black),
            ),
    );
  }
}
