import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
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

  Future<void> _newTicket() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final subjectController = TextEditingController();
    String category = widget.initialCategory ?? 'general';
    bool isSubmitting = false;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            VSPSpacing.lg,
            VSPSpacing.lg,
            VSPSpacing.lg,
            MediaQuery.of(ctx).padding.bottom +
                MediaQuery.of(ctx).viewInsets.bottom +
                VSPSpacing.lg,
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
                items: const [
                  DropdownMenuItem(value: 'account', child: Text('Account / الحساب')),
                  DropdownMenuItem(value: 'booking', child: Text('Booking / حجز')),
                  DropdownMenuItem(value: 'payment', child: Text('Payment / دفع')),
                  DropdownMenuItem(value: 'refund', child: Text('Refund / استرداد')),
                  DropdownMenuItem(value: 'tournament', child: Text('Tournament / بطولة')),
                  DropdownMenuItem(value: 'report', child: Text('Report / بلاغ')),
                  DropdownMenuItem(value: 'technical', child: Text('Technical / تقني')),
                  DropdownMenuItem(value: 'general', child: Text('General / عام')),
                ],
                onChanged: (v) => setSheetState(() => category = v ?? category),
              ),
              const SizedBox(height: VSPSpacing.lg),
              SizedBox(
                width: double.infinity,
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
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportTicketScreen(ticketId: result, title: subjectController.text.trim()),
        ),
      );
    }
    subjectController.dispose();
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
              stream: _repo.streamSupportTickets(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(VSPSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 32),
                          const SizedBox(height: VSPSpacing.md),
                          Text(
                            isArabic ? 'تعذر تحميل تذاكر الدعم.' : 'Could not load support tickets.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: VSPColors.textSecondary),
                          ),
                          const SizedBox(height: VSPSpacing.md),
                          TextButton(
                            onPressed: () => setState(() {}),
                            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final tickets = snapshot.data ?? [];
                if (tickets.isEmpty) {
                  return VSPEmptyState(
                    icon: Iconsax.messages_3_copy,
                    title: isArabic ? 'لا توجد تذاكر دعم' : 'No support tickets',
                    subtitle: isArabic ? 'افتح تذكرة وسيقوم فريق VSP بمتابعتها هنا.' : 'Open a ticket and the VSP team will follow it here.',
                    buttonText: isArabic ? 'فتح تذكرة' : 'Open Ticket',
                    onButtonPressed: _newTicket,
                  );
                }
                return ListView.separated(
                  padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: VSPSpacing.sm),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    final status = ticket['status']?.toString() ?? 'open';
                    final title = ticket['subject']?.toString() ?? (isArabic ? 'تذكرة دعم' : 'Support Ticket');
                    return ListTile(
                      tileColor: VSPColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.card)),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isArabic ? 'الحالة: $status' : 'Status: $status',
                        style: const TextStyle(color: VSPColors.textSecondary),
                      ),
                      trailing: const Icon(Iconsax.arrow_right_3_copy, color: VSPColors.textSecondary),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupportTicketScreen(ticketId: ticket['id'].toString(), title: title),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newTicket,
        backgroundColor: VSPColors.accent,
        child: const Icon(Iconsax.add_copy, color: Colors.black),
      ),
    );
  }
}
